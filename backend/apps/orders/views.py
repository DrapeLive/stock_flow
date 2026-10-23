from datetime import timedelta
from functools import partial

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import Exists, F, OuterRef, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet

from apps.accounts.permissions import (
    IsAdmin,
    IsAgent,
    IsAgentOrAdmin,
    admin_business,
    check_admin_pin,
)
from apps.agents.models import Agent, AgentItem
from apps.items.models import ItemVariantSize
from apps.notification.utils import notify_user_safely
from apps.orders.models import Order, OrderItem, OrderLog, UserViewedOrder
from apps.orders.serializers import (
    AddOrderItemSerializer,
    AdminDraftOrderSerializer,
    InvoiceSerializer,
    OrderItemSerializer,
    OrderSerializer,
    UnpackedOrderItemSerializer,
)
from apps.orders.utils import SIZE_MAPPING, get_piece_count

User = get_user_model()


class OrderPagination(PageNumberPagination):
    page_size = 50
    page_size_query_param = "page_size"
    max_page_size = 200


def _build_snapshot(order):
    """Build a list of dicts representing all OrderItems for reservation snapshot."""
    return [
        {
            "item_id": oi.item_id,
            "variant_id": oi.variant_id,
            "size_group": oi.size_group,
            "item_type": oi.item_type,
            "item_name": oi.item_name,
            "item_price": str(oi.item_price),
            "variant_image": oi.variant_image,
            "size": oi.size,
            "quantity": oi.quantity,
            "packed_quantity": oi.packed_quantity,
        }
        for oi in order.items.all()
    ]


def _is_creator(user, order):
    """Whether ``user`` is the creator/owner of a draft order.

    Orders created after the ``created_by`` migration are owned strictly by
    ``created_by``. Legacy drafts have ``created_by`` NULL and are owned by the
    agent the order belongs to.
    """
    if order.created_by_id is not None:
        return order.created_by_id == user.id
    return bool(order.agent_id) and order.agent.user_id == user.id


def _edit_access_error(user, order):
    """Return a 403 ``Response`` when ``user`` may not edit ``order``, else None.

    An admin may start/save/cancel an edit on any order inside their business
    scope (mirroring every other admin order action), including an order that
    belongs to an agent, because the edit session can be the admin's own. Agents
    remain limited to their own orders.
    """
    if user.role == "ADMIN":
        biz = admin_business(user)
        if biz and not order.items.filter(item_type=biz).exists():
            return Response(
                {"error": "This order is outside your business type"},
                status=status.HTTP_403_FORBIDDEN,
            )
        return None

    if order.agent_id and order.agent.user_id == user.id:
        return None
    return Response({"error": "Unauthorized"}, status=status.HTTP_403_FORBIDDEN)


def _reap_stale_drafts(user):
    """Delete stale DRAFT orders using role-based expiry (Option A lazy sweep).

    * Agents: drafts they created (or legacy drafts owned via their agent FK)
      older than 30 minutes.
    * Admins: drafts they created older than ``ADMIN_DRAFT_EXPIRY_MINUTES``.
    """
    if user.role == "ADMIN":
        cutoff = timezone.now() - timedelta(
            minutes=getattr(settings, "ADMIN_DRAFT_EXPIRY_MINUTES", 30)
        )
        stale_orders = Order.objects.filter(
            status="DRAFT", created_by=user, created_at__lt=cutoff
        )
        _delete_stale_drafts(stale_orders)
        return

    cutoff = timezone.now() - timedelta(minutes=30)
    stale_orders = Order.objects.filter(
        status="DRAFT",
        agent__user=user,
        created_at__lt=cutoff,
    ).filter(Q(created_by=user) | Q(created_by__isnull=True))
    _delete_stale_drafts(stale_orders)


def _delete_stale_drafts(orders):
    """Release stock held by draft lines before removing expired orders."""
    for order_id in orders.values_list("id", flat=True):
        with transaction.atomic():
            try:
                order = Order.objects.select_for_update().get(
                    pk=order_id, status="DRAFT"
                )
            except Order.DoesNotExist:
                continue
            for order_item in order.items.select_related("item", "variant"):
                if order_item.stock_reserved:
                    _return_reserved_stock_for_item(order_item)
            order.delete()


def _exclude_partial_dispatch_bundles(queryset):
    """Keep partial bundles reachable by detail links, not as order-list rows."""
    partial_dispatch_logs = OrderLog.objects.filter(
        order_id=OuterRef("pk"),
        action="DISPATCHED",
        details__partial=True,
    )
    return queryset.annotate(
        _is_partial_dispatch_bundle=Exists(partial_dispatch_logs)
    ).filter(_is_partial_dispatch_bundle=False)


def _revert_edit(order):
    """Restore OrderItems from reservation_snapshot and revert to pre-edit status."""
    with transaction.atomic():
        order.items.all().delete()
        for snap in order.reservation_snapshot:
            OrderItem.objects.create(
                order=order,
                item_id=snap["item_id"],
                variant_id=snap["variant_id"],
                size_group=snap["size_group"],
                item_type=snap["item_type"],
                item_name=snap["item_name"],
                item_price=snap["item_price"],
                variant_image=snap.get("variant_image"),
                size=snap.get("size", ""),
                quantity=snap["quantity"],
                packed_quantity=snap.get("packed_quantity", 0),
                stock_reserved=True,
            )
        order.reservation_snapshot = []
        order.editing_started_at = None
        order.status = order.previous_edit_status or "PENDING"
        order.previous_edit_status = None
        order.save()


def place_draft_order(order, data):
    """Place a DRAFT order and transition to PENDING.

    New draft lines already hold stock. Legacy/unreserved lines are checked
    and reserved here. Admin draft-accept shares this exact transaction.
    """
    out_of_stock_items = []

    admin_ids = set()
    super_admin_ids = User.objects.filter(is_superuser=True).values_list(
        "id", flat=True
    )

    admin_ids.update(super_admin_ids)
    admins = User.objects.filter(role="ADMIN")

    expected_delivery_date = data.get("expected_delivery_date")
    preferred_transport = data.get("preferred_transport")
    notes = data.get("notes")

    with transaction.atomic():
        order = Order.objects.select_for_update().get(pk=order.pk)
        if order.status != "DRAFT":
            return Response(
                {"error": "This order has already been placed."},
                status=status.HTTP_409_CONFLICT,
            )

        for order_item in order.items.select_related("item", "variant"):
            if order_item.stock_reserved:
                continue
            if order_item.item is None or order_item.item.is_deleted:
                continue

            matched_admins = User.objects.filter(
                role="ADMIN",
                brand=order_item.item.brand,
                business=order_item.item.type,
            ).values_list("id", flat=True)

            admin_ids.update(matched_admins)

            item_type = order_item.item.type
            required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

            for size in required_sizes:
                try:
                    size_obj = ItemVariantSize.objects.select_for_update().get(
                        item_variant=order_item.variant,
                        size=size,
                    )

                except ItemVariantSize.DoesNotExist:
                    out_of_stock_items.append(
                        {
                            "item_name": order_item.item_name,
                            "size_group": order_item.size_group,
                            "size": size,
                            "required": order_item.quantity,
                            "available": 0,
                            "order_item_id": order_item.id,
                        }
                    )
                    continue

                if size_obj.stock < order_item.quantity:
                    out_of_stock_items.append(
                        {
                            "item_name": order_item.item_name,
                            "size_group": order_item.size_group,
                            "size": size,
                            "required": order_item.quantity,
                            "available": size_obj.stock,
                            "order_item_id": order_item.id,
                        }
                    )

        if out_of_stock_items:
            agent_user_id = order.agent.user_id if order.agent else None
            if agent_user_id:
                notify_user_safely(
                    agent_user_id,
                    "Items Out of Stock",
                    f"{len(out_of_stock_items)} item(s) in your order are out of stock",
                )

            for admin_id in admin_ids:
                notify_user_safely(
                    admin_id,
                    "Stock Alert",
                    f"Order #{order.id} has {len(out_of_stock_items)} out-of-stock item(s)",
                )

            return Response(
                {
                    "error": "Some items are no longer available. Another agent may have placed an order.",
                    "out_of_stock_items": out_of_stock_items,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        drained = set()
        for order_item in order.items.select_related("item", "variant"):
            if order_item.stock_reserved:
                continue
            if order_item.item is None or order_item.item.is_deleted:
                continue

            item_type = order_item.item.type
            required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

            for size in required_sizes:
                ItemVariantSize.objects.filter(
                    item_variant=order_item.variant,
                    size=size,
                ).update(
                    stock=F("stock") - order_item.quantity,
                    stock_updated_at=timezone.now(),
                )
                drained.add((order_item.variant_id, size))
            order_item.stock_reserved = True
            order_item.save(update_fields=["stock_reserved"])

        now_out_of_stock = []
        for variant_id, size in drained:
            try:
                ivs = ItemVariantSize.objects.select_related(
                    "item_variant__item"
                ).get(item_variant_id=variant_id, size=size, stock=0)
            except ItemVariantSize.DoesNotExist:
                continue
            now_out_of_stock.append(ivs)
            if len(now_out_of_stock) >= 20:
                break
        if now_out_of_stock:
            names = ", ".join(
                f"{ivs.item_variant.item.name} ({ivs.size})"
                for ivs in now_out_of_stock
            )
            for admin_id in admin_ids:
                transaction.on_commit(
                    partial(
                        notify_user_safely,
                        admin_id,
                        "Item Out of Stock",
                        f"Out of stock: {names}",
                    ),
                    robust=True,
                )

        order.status = "PENDING"
        if expected_delivery_date:
            order.expected_delivery_date = expected_delivery_date

        if preferred_transport:
            from transports.models import Transport

            try:
                order.preferred_transport = Transport.objects.get(
                    id=preferred_transport
                )
            except Transport.DoesNotExist:
                pass
        if notes:
            order.notes = notes

        order.save()

        total_price = 0
        for oi in order.items.select_related("item"):
            if oi.item is None or oi.item.is_deleted:
                continue
            piece_count = get_piece_count(
                oi.size_group, oi.item_type if oi.item_type else "gents"
            )
            total_price += (
                float(oi.item_price or 0) * oi.quantity * piece_count
            )
        customer_name = order.customer.name if order.customer else ""
        order_detail = f"{customer_name} · ₹{total_price:,.2f}"

        for id in admin_ids:
            transaction.on_commit(
                partial(
                    notify_user_safely,
                    id,
                    "New Order",
                    order_detail,
                    data={"order_id": str(order.id)},
                ),
                robust=True,
            )

    return Response(
        {
            "message": "Order placed successfully",
            "order_id": order.id,
        }
    )


class PlaceOrderView(APIView):
    permission_classes = [IsAgentOrAdmin]

    @extend_schema(
        summary="Place a DRAFT order",
        request=None,
        responses={200: None, 400: None, 403: None},
    )
    def post(self, request, order_id):
        order = get_object_or_404(Order, id=order_id)

        # Admins may only place a draft order they created themselves.
        if request.user.role == "ADMIN" and (
            order.status != "DRAFT" or not _is_creator(request.user, order)
        ):
            return Response(
                {"error": "An admin can only place a draft order they created"},
                status=status.HTTP_403_FORBIDDEN,
            )

        if order.status != "DRAFT":
            return Response(
                {"error": "Only DRAFT orders can be placed"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not _is_creator(request.user, order):
            return Response(
                {"error": "You can only place your own draft orders"},
                status=status.HTTP_403_FORBIDDEN,
            )

        if not order.items.exists():
            return Response(
                {"error": "Cannot place an empty order"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return place_draft_order(order, request.data)


def _is_agent_created_draft(order):
    """Whether ``order`` is an abandoned draft owned by an agent.

    Mirrors the ownership rule used by ``_reap_stale_drafts``: an order
    created by an agent user, or a legacy draft (``created_by`` NULL) that
    belongs to an agent. Admin-created drafts are rejected here so they keep
    flowing through the normal place-order endpoint.
    """
    if order.agent_id is None:
        return False
    if order.created_by_id is None:
        return True
    return order.created_by.role == "AGENT"


def _agent_draft_guard(user, order, rejected=False):
    """Shared validation for the admin abandoned-draft endpoints.

    Returns a 4xx ``Response`` when ``order`` may not be actioned, else
    ``None``. Check order: status -> agent-created -> business scope ->
    30-minute window -> empty.
    """
    if order.status != "DRAFT":
        return Response(
            {
                "error": (
                    "Only DRAFT orders can be rejected"
                    if rejected
                    else "Only DRAFT orders can be placed"
                )
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    if not _is_agent_created_draft(order):
        return Response(
            {"error": "Only abandoned agent drafts can be actioned"},
            status=status.HTTP_403_FORBIDDEN,
        )

    biz = admin_business(user)
    if biz and not order.items.filter(item_type=biz).exists():
        return Response(
            {"error": "This order is outside your business type"},
            status=status.HTTP_403_FORBIDDEN,
        )

    if order.created_at < timezone.now() - timedelta(minutes=30):
        return Response(
            {"error": "This draft has expired"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if not order.items.exists():
        return Response(
            {"error": "Cannot place an empty order"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    return None


class AdminDraftAcceptView(APIView):
    """Accept an abandoned agent DRAFT with admin PIN confirmation."""

    permission_classes = [IsAdmin]

    @extend_schema(
        summary="Accept an abandoned agent DRAFT order",
        request=None,
        responses={200: None, 400: None, 403: None, 404: None},
    )
    def post(self, request, order_id):
        order = get_object_or_404(Order, id=order_id)

        denial = _agent_draft_guard(request.user, order)
        if denial:
            return denial

        pin_error = check_admin_pin(request)
        if pin_error:
            return pin_error

        with transaction.atomic():
            locked = Order.objects.select_for_update().get(id=order_id)
            if locked.status != "DRAFT":
                return Response(
                    {"error": "Only DRAFT orders can be placed"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            response = place_draft_order(locked, request.data)

            if response.status_code == status.HTTP_200_OK:
                agent_user_id = locked.agent.user_id if locked.agent else None
                if agent_user_id:
                    customer_name = locked.customer.name if locked.customer else ""
                    transaction.on_commit(
                        partial(
                            notify_user_safely,
                            agent_user_id,
                            "Order Placed",
                            f"Your unfinished order #{locked.id} for {customer_name}"
                            " was accepted by admin and is now pending",
                            data={"type": "order_status", "order_id": str(locked.id), "customer_name": customer_name},
                        ),
                        robust=True,
                    )

        return response


class AdminDraftRejectView(APIView):
    """Discard an abandoned agent DRAFT. Admin PIN required (superusers skip)."""

    permission_classes = [IsAdmin]

    @extend_schema(
        summary="Reject an abandoned agent DRAFT order",
        request=None,
        responses={200: None, 400: None, 403: None, 404: None},
    )
    def post(self, request, order_id):
        order = get_object_or_404(Order, id=order_id)

        denial = _agent_draft_guard(request.user, order, rejected=True)
        if denial:
            return denial

        pin_error = check_admin_pin(request)
        if pin_error:
            return pin_error

        with transaction.atomic():
            locked = Order.objects.select_for_update().get(id=order_id)
            if locked.status != "DRAFT":
                return Response(
                    {"error": "Only DRAFT orders can be rejected"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            agent_user_id = locked.agent.user_id if locked.agent else None
            customer_name = locked.customer.name if locked.customer else ""
            for order_item in locked.items.select_related("item", "variant"):
                _return_reserved_stock_for_item(order_item)
            locked.delete()

            if agent_user_id:
                transaction.on_commit(
                    partial(
                        notify_user_safely,
                        agent_user_id,
                        "Draft Discarded",
                        f"Your unfinished order #{order_id} for {customer_name}"
                        " was discarded",
                        data={"type": "order_status", "order_id": str(order_id), "customer_name": customer_name},
                    ),
                    robust=True,
                )

        return Response(
            {"message": "Draft rejected", "order_id": order_id}
        )


def return_stock_for_item(order_item):
    """Return stock to warehouse for an order item."""
    if order_item.item is None:
        return

    item_type = order_item.item.type
    required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

    for size in required_sizes:
        ItemVariantSize.objects.filter(
            item_variant=order_item.variant, size=size
        ).update(
            stock=F("stock") + order_item.quantity,
            stock_updated_at=timezone.now(),
        )


def _return_reserved_stock_for_item(order_item):
    """Release only stock actually reserved by this order line."""
    if not order_item.stock_reserved:
        return
    return_stock_for_item(order_item)


def _stock_shortages(order_item):
    """Lock and report missing/insufficient size rows for one order line."""
    if order_item.item is None or order_item.item.is_deleted:
        return []
    required_sizes = SIZE_MAPPING[order_item.item.type][order_item.size_group]
    shortages = []
    for size in required_sizes:
        try:
            size_obj = ItemVariantSize.objects.select_for_update().get(
                item_variant=order_item.variant, size=size
            )
        except ItemVariantSize.DoesNotExist:
            available = 0
        else:
            available = size_obj.stock
        if available < order_item.quantity:
            shortages.append({
                "item_name": order_item.item_name,
                "size_group": order_item.size_group,
                "size": size,
                "required": order_item.quantity,
                "available": available,
                "order_item_id": order_item.id,
            })
    return shortages


def _deduct_stock_for_item(order_item):
    if order_item.item is None or order_item.item.is_deleted:
        return
    required_sizes = SIZE_MAPPING[order_item.item.type][order_item.size_group]
    for size in required_sizes:
        ItemVariantSize.objects.filter(
            item_variant=order_item.variant, size=size
        ).update(
            stock=F("stock") - order_item.quantity,
            stock_updated_at=timezone.now(),
        )


class StartEditView(APIView):
    permission_classes = [IsAgentOrAdmin]

    @extend_schema(
        summary="Start editing a PENDING or PACKED order",
        request=None,
        responses={200: None, 400: None, 403: None},
    )
    def post(self, request, order_id):
        with transaction.atomic():
            order = get_object_or_404(
                Order.objects.select_for_update(), id=order_id
            )

            if order.status not in ("PENDING", "PACKED"):
                return Response(
                    {"error": "Only PENDING or PACKED orders can be edited"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            denied = _edit_access_error(request.user, order)
            if denied:
                return denied

            order.reservation_snapshot = _build_snapshot(order)
            order.editing_started_at = timezone.now()
            order.previous_edit_status = order.status
            order.status = "EDITING"
            order.save(
                update_fields=[
                    "reservation_snapshot",
                    "editing_started_at",
                    "previous_edit_status",
                    "status",
                ]
            )
            # The original inventory remains held by the snapshot during edit.
            # Edited lines must not claim that same stock a second time.
            order.items.update(stock_reserved=False)
            # Remove viewed entries for non-pending/packed orders
            UserViewedOrder.objects.filter(order=order).delete()

            OrderLog.objects.create(
                order=order,
                action="EDIT_STARTED",
                details={"items_count": len(order.reservation_snapshot)},
                performed_by=request.user,
            )

            return Response(
                {
                    "message": "Edit started",
                    "status": order.status,
                    "order_id": order.id,
                }
            )


class SaveEditView(APIView):
    permission_classes = [IsAgentOrAdmin]

    @extend_schema(
        summary="Save edits made to a PENDING/PACKED order",
        request=None,
        responses={200: None, 400: None, 403: None},
    )
    def post(self, request, order_id):
        order = get_object_or_404(Order, id=order_id)

        denied = _edit_access_error(request.user, order)
        if denied:
            return denied

        if order.status != "EDITING":
            return Response(
                {"error": "Order is not in editing mode"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        with transaction.atomic():
            for snap in order.reservation_snapshot:
                item_type = snap["item_type"]
                required_sizes = SIZE_MAPPING[item_type][snap["size_group"]]
                for size in required_sizes:
                    ItemVariantSize.objects.filter(
                        item_variant_id=snap["variant_id"], size=size
                    ).update(
                        stock=F("stock") + snap["quantity"],
                        stock_updated_at=timezone.now(),
                    )

            out_of_stock_items = []
            for order_item in order.items.select_related("item", "variant"):
                if order_item.item is None or order_item.item.is_deleted:
                    continue

                item_type = order_item.item.type
                required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

                for size in required_sizes:
                    try:
                        size_obj = ItemVariantSize.objects.select_for_update().get(
                            item_variant=order_item.variant, size=size
                        )
                    except ItemVariantSize.DoesNotExist:
                        out_of_stock_items.append(
                            {
                                "item_name": order_item.item_name,
                                "size_group": order_item.size_group,
                                "size": size,
                                "required": order_item.quantity,
                                "available": 0,
                                "order_item_id": order_item.id,
                            }
                        )
                        continue

                    if size_obj.stock < order_item.quantity:
                        out_of_stock_items.append(
                            {
                                "item_name": order_item.item_name,
                                "size_group": order_item.size_group,
                                "size": size,
                                "required": order_item.quantity,
                                "available": size_obj.stock,
                                "order_item_id": order_item.id,
                            }
                        )

            if out_of_stock_items:
                # Build admin_ids the same way PlaceOrderView does
                admin_ids = set(
                    User.objects.filter(is_superuser=True).values_list("id", flat=True)
                )
                for order_item in order.items.select_related("item"):
                    if order_item.item is None or order_item.item.is_deleted:
                        continue
                    matched = User.objects.filter(
                        role="ADMIN",
                        brand=order_item.item.brand,
                        business=order_item.item.type,
                    ).values_list("id", flat=True)
                    admin_ids.update(matched)

                agent_user_id = order.agent.user_id if order.agent else None
                if agent_user_id:
                    notify_user_safely(
                        agent_user_id,
                        "Items Out of Stock",
                        f"{len(out_of_stock_items)} item(s) in your edited order are out of stock",
                    )

                for admin_id in admin_ids:
                    notify_user_safely(
                        admin_id,
                        "Stock Alert",
                        f"Order #{order.id} has {len(out_of_stock_items)} out-of-stock item(s) after edit",
                    )

                transaction.set_rollback(True)
                return Response(
                    {
                        "error": "Some items are no longer available. Another agent may have placed an order.",
                        "out_of_stock_items": out_of_stock_items,
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            for order_item in order.items.select_related("item", "variant"):
                if order_item.item is None or order_item.item.is_deleted:
                    continue

                item_type = order_item.item.type
                required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

                for size in required_sizes:
                    ItemVariantSize.objects.filter(
                        item_variant=order_item.variant, size=size
                    ).update(
                        stock=F("stock") - order_item.quantity,
                        stock_updated_at=timezone.now(),
                    )
                order_item.stock_reserved = True
                order_item.save(update_fields=["stock_reserved"])

            expected_delivery_date = request.data.get("expected_delivery_date")
            preferred_transport = request.data.get("preferred_transport")
            notes = request.data.get("notes")

            order.reservation_snapshot = []
            order.editing_started_at = None
            order.status = order.previous_edit_status or "PENDING"
            order.previous_edit_status = None

            if expected_delivery_date:
                order.expected_delivery_date = expected_delivery_date
            else:
                order.expected_delivery_date = None

            if preferred_transport:
                from transports.models import Transport

                try:
                    order.preferred_transport = Transport.objects.get(
                        id=preferred_transport
                    )
                except Transport.DoesNotExist:
                    pass
            else:
                order.preferred_transport = None

            if notes:
                order.notes = notes

            order.save()

        OrderLog.objects.create(
            order=order,
            action="EDIT_SAVED",
            details={"items_count": order.items.count()},
            performed_by=request.user,
        )

        return Response(
            {
                "message": "Order saved successfully",
                "order_id": order.id,
                "status": order.status,
            }
        )


class OrderViewSet(ModelViewSet):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = OrderPagination

    def get_queryset(self):

        user = self.request.user

        if self.action == "list":
            _reap_stale_drafts(user)

            cutoff = timezone.now() - timedelta(minutes=15)
            stale_editing = Order.objects.filter(
                status="EDITING",
                editing_started_at__lt=cutoff,
            ).filter(
                Q(agent__user=user)
                | Q(
                    logs__action="EDIT_STARTED",
                    logs__performed_by=user,
                )
            )
            for o in stale_editing:
                _revert_edit(o)

        qs = Order.objects.prefetch_related("items__variant", "items__item").order_by(
            "-created_at"
        )

        if self.action == "list":
            archive_cutoff = timezone.now() - timedelta(days=30)
            qs = qs.exclude(
                status="DISPATCHED",
                dispatched_at__isnull=False,
                dispatched_at__lte=archive_cutoff,
            )
            qs = _exclude_partial_dispatch_bundles(qs)

        customer_id = self.request.query_params.get("customer")
        if customer_id:
            qs = qs.filter(customer_id=customer_id)

        from_date = self.request.query_params.get("from_date")
        if from_date:
            qs = qs.filter(created_at__date__gte=from_date)

        to_date = self.request.query_params.get("to_date")
        if to_date:
            qs = qs.filter(created_at__date__lte=to_date)

        agent_id = self.request.query_params.get("agent")
        if agent_id and user.role == "ADMIN":
            qs = qs.filter(agent_id=agent_id)

        statuses = self.request.query_params.getlist("status")

        if statuses:
            qs = qs.filter(status__in=[s.upper() for s in statuses])
        if user.role == "ADMIN":
            biz = admin_business(user)

            # D2: an admin only sees their own drafts; all non-draft orders
            # remain visible as before.
            own_draft = Q(status="DRAFT") & Q(created_by=user)

            if biz:
                # A draft may have no items yet, so the business-type filter
                # must not hide an admin's own draft. Apply the type filter
                # only to non-draft orders.
                qs = qs.filter(
                    own_draft | (~Q(status="DRAFT") & Q(items__item_type=biz))
                ).distinct()
            else:
                qs = qs.filter(own_draft | ~Q(status="DRAFT"))

            search = self.request.query_params.get("search")
            if search:
                qs = qs.filter(
                    Q(customer__name__icontains=search)
                    | Q(agent__user__username__icontains=search)
                    | Q(id__icontains=search)
                ).distinct()

            return qs

        search = self.request.query_params.get("search")
        if search:
            qs = qs.filter(
                Q(customer__name__icontains=search)
                | Q(agent__user__username__icontains=search)
                | Q(id__icontains=search)
            ).distinct()

        return qs.filter(agent__user=user)

    @extend_schema(
        summary="Create an order (DRAFT)",
        responses={201: OrderSerializer, 400: None},
    )
    def create(self, request, *args, **kwargs):
        return super().create(request, *args, **kwargs)

    def perform_create(self, serializer):
        user = self.request.user

        if user.role == "ADMIN":
            agent_id = self.request.data.get("agent")
            if not agent_id:
                raise ValidationError(
                    {"agent": "An agent is required when an admin creates an order."}
                )

            agent = (
                Agent.objects.filter(id=agent_id).select_related("user").first()
            )
            if agent is None:
                raise ValidationError(
                    {"agent": "The selected agent does not exist."}
                )
            if not agent.is_active:
                raise ValidationError(
                    {
                        "agent": (
                            "The selected agent is inactive and cannot be assigned orders."
                        )
                    }
                )
            if not agent.user.is_active:
                raise ValidationError(
                    {
                        "agent": (
                            "The selected agent's user account is inactive."
                        )
                    }
                )

            serializer.save(agent=agent, created_by=user)
            return

        serializer.save(agent=user.agent, created_by=user)

    def update(self, request, *args, **kwargs):
        order = self.get_object()
        new_status = request.data.get("status")

        # Dispatch must go through the dedicated endpoint so unpacked stock is
        # returned to the warehouse.
        if new_status == "DISPATCHED":
            return Response(
                {"error": "Use the dispatch endpoint to mark an order as dispatched"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if order.status == "DRAFT":
            if not _is_creator(request.user, order):
                return Response(
                    {"error": "You can only edit your own draft orders"},
                    status=status.HTTP_403_FORBIDDEN,
                )
            if new_status and new_status != "DRAFT":
                return Response(
                    {
                        "error": "A draft order can only be placed via the place-order endpoint"
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

        return super().update(request, *args, **kwargs)

    def destroy(self, request, pk=None):
        pin_error = check_admin_pin(request)
        if pin_error:
            return pin_error
        order = self.get_object()

        if order.status == "DRAFT":
            with transaction.atomic():
                locked = Order.objects.select_for_update().get(pk=order.pk)
                for order_item in locked.items.select_related("item", "variant"):
                    _return_reserved_stock_for_item(order_item)
                locked.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        else:
            with transaction.atomic():
                for order_item in order.items.select_related("item", "variant"):
                    return_stock_for_item(order_item)

                OrderLog.objects.create(
                    order=order,
                    action="ORDER_DELETED",
                    details={
                        "customer": order.customer.name,
                        "items_count": order.items.count(),
                        "status": order.status,
                    },
                    performed_by=request.user,
                )

        order.delete()

        return Response(status=status.HTTP_204_NO_CONTENT)

    @extend_schema(summary="Dispatch all or part of a PENDING/PACKED order")
    @action(detail=True, methods=["post"], url_path="dispatch")
    def dispatch_order(self, request, pk=None):
        order = self.get_object()
        dispatch_type = request.data.get("dispatch_type", "full")
        if dispatch_type not in ("full", "partial"):
            return Response(
                {"error": "dispatch_type must be 'full' or 'partial'"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        transport_company_id = request.data.get("transport_company")
        lr_number = request.data.get("lr_number", "")

        with transaction.atomic():
            order = Order.objects.select_for_update().get(pk=order.pk)
            if order.status not in ["PENDING", "PACKED"]:
                return Response(
                    {"error": "Only PENDING or PACKED orders can be dispatched"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            item_quantities = []
            for order_item in order.items.select_related("item", "variant"):
                piece_count = get_piece_count(
                    order_item.size_group, order_item.item_type or "gents"
                )
                packed_sets = min(
                    order_item.quantity,
                    (order_item.packed_quantity or 0) // max(piece_count, 1),
                )
                item_quantities.append((order_item, packed_sets))

            if dispatch_type == "partial":
                packed_lines = [
                    (item, packed_sets)
                    for item, packed_sets in item_quantities
                    if packed_sets > 0
                ]
                if not packed_lines:
                    return Response(
                        {"error": "There are no fully packed sets to dispatch."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                if all(
                    item.quantity == packed_sets
                    for item, packed_sets in item_quantities
                ):
                    return Response(
                        {"error": "All items are packed; use full dispatch."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                now = timezone.now()
                pending_order = Order.objects.create(
                    customer=order.customer,
                    agent=order.agent,
                    created_by=order.created_by,
                    split_from=order,
                    status="PENDING",
                    expected_delivery_date=order.expected_delivery_date,
                    preferred_transport=order.preferred_transport,
                    notes=order.notes,
                )
                # The remainder is still the same customer order, so keep its
                # original order date instead of using the split timestamp.
                Order.objects.filter(pk=pending_order.pk).update(
                    created_at=order.created_at
                )

                shipped_details = []
                for order_item, packed_sets in item_quantities:
                    piece_count = get_piece_count(
                        order_item.size_group, order_item.item_type or "gents"
                    )
                    if packed_sets:
                        shipped_details.append(
                            {
                                "order_item_id": order_item.id,
                                "item_name": order_item.item_name,
                                "quantity": packed_sets,
                            }
                        )

                    remaining_sets = order_item.quantity - packed_sets
                    if remaining_sets:
                        OrderItem.objects.create(
                            order=pending_order,
                            item=order_item.item,
                            variant=order_item.variant,
                            size_group=order_item.size_group,
                            item_type=order_item.item_type,
                            item_name=order_item.item_name,
                            item_price=order_item.item_price,
                            variant_image=order_item.variant_image,
                            size=order_item.size,
                            quantity=remaining_sets,
                            packed_quantity=max(
                                0,
                                (order_item.packed_quantity or 0)
                                - packed_sets * piece_count,
                            ),
                            stock_reserved=True,
                        )
                    order_item.quantity = packed_sets
                    order_item.packed_quantity = packed_sets * piece_count
                    order_item.stock_reserved = True
                    if packed_sets:
                        order_item.save(
                            update_fields=[
                                "quantity",
                                "packed_quantity",
                                "stock_reserved",
                            ]
                        )
                    else:
                        order_item.delete()

                order.status = "DISPATCHED"
                order.dispatched_at = now
                if transport_company_id:
                    from transports.models import Transport

                    transport_company = Transport.objects.filter(
                        id=transport_company_id
                    ).first()
                    if transport_company is not None:
                        order.transport_company = transport_company
                if lr_number:
                    order.lr_number = lr_number
                order.save()

                OrderLog.objects.create(
                    order=order,
                    action="PARTIAL_DISPATCH",
                    details={
                        "remaining_order_id": pending_order.id,
                        "items": shipped_details,
                    },
                    performed_by=request.user,
                )
                OrderLog.objects.create(
                    order=order,
                    action="DISPATCHED",
                    details={
                        "partial": True,
                        "remaining_order_id": pending_order.id,
                        "packed_items": len(packed_lines),
                        "total_items": len(packed_lines),
                    },
                    performed_by=request.user,
                )
                OrderLog.objects.create(
                    order=pending_order,
                    action="PARTIAL_DISPATCH",
                    details={"dispatched_order_id": order.id},
                    performed_by=request.user,
                )
                UserViewedOrder.objects.filter(order=order).delete()
                result = {
                    "message": "Packed items dispatched successfully",
                    "dispatch_type": "partial",
                    "dispatched_order_id": order.id,
                    "remaining_order_id": pending_order.id,
                }
                agent_user_id = order.agent.user_id if order.agent else None
                if agent_user_id:
                    transaction.on_commit(
                        partial(
                            notify_user_safely,
                            agent_user_id,
                            "Order Partially Dispatched",
                            f"Packed items from {order.customer.name if order.customer else 'Customer'}'s order have been dispatched",
                            data={"type": "order_status", "order_id": str(pending_order.id), "customer_name": order.customer.name if order.customer else "Customer"},
                        ),
                        robust=True,
                    )
                return Response(result)

            for order_item, packed_sets in item_quantities:
                if order_item.item is None or order_item.item.is_deleted:
                    continue
                unpacked_sets = order_item.quantity - packed_sets
                if unpacked_sets > 0:
                    item_type = order_item.item.type
                    required_sizes = SIZE_MAPPING[item_type][order_item.size_group]
                    for size in required_sizes:
                        ItemVariantSize.objects.filter(
                            item_variant=order_item.variant, size=size
                        ).update(
                            stock=F("stock") + unpacked_sets,
                            stock_updated_at=timezone.now(),
                        )

            OrderLog.objects.create(
                order=order,
                action="DISPATCHED",
                details={
                    "packed_items": sum(
                        1 for _, packed_sets in item_quantities if packed_sets > 0
                    ),
                    "total_items": len(item_quantities),
                },
                performed_by=request.user,
            )

            order.status = "DISPATCHED"
            order.dispatched_at = timezone.now()

            if transport_company_id:
                from transports.models import Transport

                try:
                    order.transport_company = Transport.objects.get(
                        id=transport_company_id
                    )
                except Transport.DoesNotExist:
                    pass

            if lr_number:
                order.lr_number = lr_number

            order.save()

            # Remove viewed entries for non-pending/packed orders
            UserViewedOrder.objects.filter(order=order).delete()

        agent_user_id = order.agent.user_id if order.agent else None
        if agent_user_id:
            transaction.on_commit(
                partial(
                    notify_user_safely,
                    agent_user_id,
                    "Order Dispatched",
                    f"Order for {order.customer.name if order.customer else 'Customer'} has been dispatched",
                    data={"type": "order_status", "order_id": str(order.id), "customer_name": order.customer.name if order.customer else "Customer"},
                ),
                robust=True,
            )
        return Response({"message": "Order dispatched successfully", "dispatch_type": "full"})

    @extend_schema(summary="Cancel an in-progress order edit")
    @action(detail=True, methods=["post"], url_path="cancel-edit")
    def cancel_edit(self, request, pk=None):
        order = self.get_object()

        denied = _edit_access_error(request.user, order)
        if denied:
            return denied

        if order.status != "EDITING":
            return Response(
                {"error": "Order is not in editing mode"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        _revert_edit(order)

        OrderLog.objects.create(
            order=order,
            action="EDIT_CANCELLED",
            details={},
            performed_by=request.user,
        )

        return Response(
            {
                "message": "Edit cancelled",
                "order_id": order.id,
                "status": order.status,
            }
        )

    @extend_schema(summary="List order IDs viewed by the current user")
    @action(detail=False, methods=["get"], url_path="my-viewed-ids")
    def my_viewed_ids(self, request):
        """Return list of order IDs the current user has viewed."""
        viewed = UserViewedOrder.objects.filter(user=request.user).values_list(
            "order_id", flat=True
        )
        return Response(list(viewed))

    @extend_schema(summary="Mark an order as viewed by the current user")
    @action(detail=True, methods=["post"], url_path="mark-viewed")
    def mark_viewed(self, request, pk=None):
        """Mark order as viewed by current user (only for PENDING/PACKED orders)."""
        order = self.get_object()
        if order.status in ["PENDING", "PACKED"]:
            UserViewedOrder.objects.get_or_create(user=request.user, order=order)
        else:
            # Clean up any existing entries for non-pending/packed orders
            UserViewedOrder.objects.filter(user=request.user, order=order).delete()
        return Response({"message": "Viewed status updated"})

    @extend_schema(summary="List lightweight {id, status} pairs for the current user")
    @action(detail=False, methods=["get"], url_path="order-ids")
    def order_ids(self, request):
        """Return lightweight list of {id, status} for all orders (for unread count)."""
        user = request.user
        qs = Order.objects.all()

        if user.role == "ADMIN":
            biz = admin_business(user)
            if biz:
                qs = qs.filter(items__item_type=biz).distinct()
            # Admin clients hide DRAFTs entirely, so omit them here too to
            # keep badge/"All" counts consistent with the visible list.
            qs = qs.exclude(status="DRAFT")
        else:
            qs = qs.filter(agent__user=user)

        qs = _exclude_partial_dispatch_bundles(qs)

        qs = qs.values_list("id", "status")
        return Response([{"id": oid, "status": stat} for oid, stat in qs])

    @extend_schema(summary="List dispatched orders archived after 30 days")
    @action(detail=False, methods=["get"], url_path="archived")
    def get_archived(self, request):
        from datetime import timedelta

        from django.utils import timezone

        cutoff = timezone.now() - timedelta(days=30)
        user = request.user

        qs = (
            Order.objects.prefetch_related("items__variant", "items__item")
            .filter(
                status="DISPATCHED",
                dispatched_at__isnull=False,
                dispatched_at__lte=cutoff,
            )
            .order_by("-dispatched_at")
        )
        qs = _exclude_partial_dispatch_bundles(qs)

        print(f"DEBUG get_archived: qs.count()={qs.count()}")

        if user.role == "ADMIN":
            biz = admin_business(user)
            if biz:
                qs = qs.filter(items__item_type=biz).distinct()
        else:
            qs = qs.filter(agent__user=user)

        page = self.paginate_queryset(qs)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)

        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @extend_schema(
        summary="List abandoned agent DRAFT orders from the last 30 minutes"
    )
    @action(
        detail=False,
        methods=["get"],
        url_path="admin-drafts",
        permission_classes=[IsAdmin],
    )
    def admin_drafts(self, request):
        """Agent-owned, non-empty drafts still inside the 30-minute window.

        Deliberately does not call ``_reap_stale_drafts``: browsing this list
        must never change when a draft gets deleted.
        """
        cutoff = timezone.now() - timedelta(minutes=30)
        qs = (
            Order.objects.filter(
                status="DRAFT",
                agent__isnull=False,
                created_at__gte=cutoff,
            )
            .filter(Q(created_by__isnull=True) | Q(created_by__role="AGENT"))
            .filter(items__isnull=False)
            .select_related("agent__user", "customer", "created_by")
            .prefetch_related("items")
            .order_by("created_at")
        )

        biz = admin_business(request.user)
        if biz:
            qs = qs.filter(items__item_type=biz).distinct()

        page = self.paginate_queryset(qs)
        serializer = AdminDraftOrderSerializer(
            page, many=True, context={"request": request}
        )
        if page is not None:
            return self.get_paginated_response(serializer.data)

        return Response(serializer.data)


class AddOrderItemView(APIView):
    permission_classes = [IsAgentOrAdmin]

    @extend_schema(
        summary="Add an item to a DRAFT/EDITING/PENDING order",
        request=AddOrderItemSerializer,
        responses={201: None, 400: None, 403: None},
    )
    def post(self, request, order_id):

        serializer = AddOrderItemSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        order = get_object_or_404(Order, id=order_id)

        # Admins may add items to a draft order they created themselves or to
        # an order currently being edited (started via start-edit).
        if request.user.role == "ADMIN":
            is_own_draft = order.status == "DRAFT" and _is_creator(
                request.user, order
            )
            is_active_edit = order.status == "EDITING"
            if not (is_own_draft or is_active_edit):
                return Response(
                    {
                        "error": "An admin can only add items to a draft order they created or to an order being edited"
                    },
                    status=status.HTTP_403_FORBIDDEN,
                )
            if is_active_edit:
                denied = _edit_access_error(request.user, order)
                if denied:
                    return denied

        if order.status not in ("DRAFT", "EDITING", "PENDING"):
            return Response(
                {"error": "Items can only be added to DRAFT or EDITING orders"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if order.status == "DRAFT" and not _is_creator(request.user, order):
            return Response(
                {"error": "You can only add items to your own draft orders"},
                status=status.HTTP_403_FORBIDDEN,
            )

        item = serializer.validated_data["item"]
        variant = serializer.validated_data["variant"]
        qty = serializer.validated_data["quantity"]
        size_group = serializer.validated_data["size_group"]

        # D1: admins can build their own drafts without item assignments.
        if request.user.role == "AGENT" and not AgentItem.objects.filter(
            agent=request.user.agent, variant__item=item, variant=variant
        ).exists():
            return Response(
                {
                    "error": "This item is not assigned to you. Please contact admin for assignment."
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        existing = order.items.first()
        if existing and existing.item_type != item.type:
            return Response(
                {"error": f"Order can only contain items of {existing.item_type} type"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        item_type = item.type

        if size_group not in SIZE_MAPPING[item_type]:
            return Response(
                {"error": "Invalid size group"}, status=status.HTTP_400_BAD_REQUEST
            )

        with transaction.atomic():
            # Serialize item additions with placement/deletion for this order.
            order = Order.objects.select_for_update().get(pk=order.pk)
            if order.status not in ("DRAFT", "EDITING", "PENDING"):
                return Response(
                    {"error": "Items can only be added to DRAFT or EDITING orders"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if order.status == "DRAFT" and not _is_creator(request.user, order):
                return Response(
                    {"error": "You can only add items to your own draft orders"},
                    status=status.HTTP_403_FORBIDDEN,
                )
            locked_existing = order.items.first()
            if locked_existing and locked_existing.item_type != item.type:
                return Response(
                    {
                        "error": (
                            "Order can only contain items of "
                            f"{locked_existing.item_type} type"
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )
            order_item = OrderItem(
                order=order,
                item=item,
                variant=variant,
                size_group=size_group,
                item_type=item_type,
                item_name=serializer.validated_data["item_name"],
                item_price=serializer.validated_data["item_price"],
                variant_image=serializer.validated_data.get("variant_image"),
                size=serializer.validated_data.get("size", ""),
                quantity=qty,
            )
            if order.status == "DRAFT":
                shortages = _stock_shortages(order_item)
                if shortages:
                    return Response(
                        {
                            "error": "Insufficient stock to reserve this draft item.",
                            "out_of_stock_items": shortages,
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                _deduct_stock_for_item(order_item)
                order_item.stock_reserved = True
            order_item.save()

        return Response(
            {"message": "Item added successfully"}, status=status.HTTP_201_CREATED
        )


class DeleteOrderItemView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        summary="Delete an item from an order",
        responses={200: None, 403: None, 404: None},
    )
    def delete(self, request, order_id, item_id):

        order = get_object_or_404(Order, id=order_id)

        if order.status == "DRAFT" and not _is_creator(request.user, order):
            return Response(
                {"error": "You can only edit your own draft orders"},
                status=status.HTTP_403_FORBIDDEN,
            )

        order_item = get_object_or_404(OrderItem, id=item_id, order=order)

        if order.status not in ("DRAFT", "EDITING"):
            if order_item.item is not None and not order_item.item.is_deleted:
                item_type = order_item.item.type
                required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

                with transaction.atomic():
                    for size in required_sizes:
                        ItemVariantSize.objects.filter(
                            item_variant=order_item.variant, size=size
                        ).update(
                            stock=F("stock") + order_item.quantity,
                            stock_updated_at=timezone.now(),
                        )

                OrderLog.objects.create(
                    order=order,
                    action="ITEM_DELETED",
                    details={
                        "item_name": order_item.item_name,
                        "size_group": order_item.size_group,
                        "quantity": order_item.quantity,
                        "stock_returned": True,
                    },
                    performed_by=request.user,
                )
        elif order.status == "EDITING":
            OrderLog.objects.create(
                order=order,
                action="ITEM_DELETED",
                details={
                    "item_name": order_item.item_name,
                    "size_group": order_item.size_group,
                    "quantity": order_item.quantity,
                    "stock_returned": False,
                },
                performed_by=request.user,
            )
        else:
            with transaction.atomic():
                order = Order.objects.select_for_update().get(pk=order.pk)
                order_item = OrderItem.objects.select_for_update().get(
                    pk=order_item.pk, order=order
                )
                _return_reserved_stock_for_item(order_item)
                OrderLog.objects.create(
                    order=order,
                    action="ITEM_DELETED",
                    details={
                        "item_name": order_item.item_name,
                        "size_group": order_item.size_group,
                        "quantity": order_item.quantity,
                        "stock_returned": order_item.stock_reserved,
                    },
                    performed_by=request.user,
                )
                order_item.delete()
            return Response({"message": "Item Deleted Successfully"})

        order_item.delete()

        return Response({"message": "Item Deleted Successfully"})


class InvoiceView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        summary="Get the invoice for an order",
        responses={200: InvoiceSerializer, 404: None},
    )
    def get(self, request, order_id):
        order = get_object_or_404(
            Order.objects.prefetch_related("items__item__brand"), id=order_id
        )

        biz = admin_business(request.user)
        if biz and not order.items.filter(item_type=biz).exists():
            return Response({"error": "Not found"}, status=404)

        serializer = InvoiceSerializer(order, context={"request": request})

        return Response(serializer.data)


class OrderLogsView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        summary="Get the audit log for an order",
        responses={200: None, 403: None, 404: None},
    )
    def get(self, request, order_id):
        order = get_object_or_404(Order, id=order_id)

        if request.user.role == "ADMIN":
            biz = admin_business(request.user)
            if biz and not order.items.filter(item_type=biz).exists():
                return Response({"error": "Not found"}, status=404)
        elif order.agent.user != request.user:
            return Response({"error": "Unauthorized"}, status=403)

        logs = order.logs.all().order_by("-created_at")

        result = []
        for log in logs:
            user_name = None
            if log.performed_by:
                user_name = log.performed_by.username

            result.append(
                {
                    "id": log.id,
                    "action": log.action,
                    "details": log.details,
                    "performed_by": user_name,
                    "created_at": log.created_at.isoformat(),
                }
            )

        return Response(result)


class OrderItemViewSet(ModelViewSet):
    queryset = OrderItem.objects.all()
    serializer_class = OrderItemSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):

        user = self.request.user

        qs = OrderItem.objects.all()
        if user.role == "ADMIN":
            biz = admin_business(user)
            if biz:
                qs = qs.filter(item_type=biz)
            return qs

        return qs.filter(order__agent__user=user)

    def update(self, request, *args, **kwargs):
        order_item = self.get_object()
        order = order_item.order

        if order.status == "DRAFT" and not _is_creator(request.user, order):
            return Response(
                {"error": "You can only edit your own draft orders"},
                status=status.HTTP_403_FORBIDDEN,
            )

        if order.status not in ["DRAFT", "EDITING", "PENDING", "PACKED"]:
            return Response(
                {"error": "Cannot edit items in this order status"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        old_quantity = order_item.quantity
        old_size_group = order_item.size_group

        new_quantity = request.data.get("quantity", old_quantity)
        new_size_group = request.data.get("size_group", old_size_group)

        item_type = order_item.item_type
        if new_size_group not in SIZE_MAPPING.get(item_type, {}):
            return Response(
                {"error": "Invalid size group for this item type"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if order.status == "EDITING":
            order_item.quantity = new_quantity
            order_item.size_group = new_size_group
            order_item.save()
            return super().update(request, *args, **kwargs)

        if order.status == "DRAFT":
            if "item" in request.data or "variant" in request.data:
                return Response(
                    {"error": "Remove and re-add an item to change its product or variant."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            try:
                new_quantity = int(new_quantity)
            except (TypeError, ValueError):
                return Response(
                    {"quantity": "A valid integer is required."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if new_quantity <= 0:
                return Response(
                    {"quantity": "Must be greater than zero."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            with transaction.atomic():
                locked_order = Order.objects.select_for_update().get(pk=order.pk)
                if locked_order.status != "DRAFT":
                    return Response(
                        {"error": "The draft is no longer editable."},
                        status=status.HTTP_409_CONFLICT,
                    )
                order_item = OrderItem.objects.select_for_update().get(
                    pk=order_item.pk, order=locked_order
                )
                _return_reserved_stock_for_item(order_item)
                order_item.quantity = new_quantity
                order_item.size_group = new_size_group
                shortages = _stock_shortages(order_item)
                if shortages:
                    transaction.set_rollback(True)
                    return Response(
                        {
                            "error": "Insufficient stock to update this draft item.",
                            "out_of_stock_items": shortages,
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                _deduct_stock_for_item(order_item)
                order_item.stock_reserved = True
                order_item.save()
            return super().update(request, *args, **kwargs)

        if order.status != "DRAFT":
            with transaction.atomic():
                if old_quantity != new_quantity or old_size_group != new_size_group:
                    return_stock_for_item(order_item)

                    if order_item.item:
                        item_type = order_item.item.type
                        required_sizes = SIZE_MAPPING[item_type][new_size_group]

                        for size in required_sizes:
                            try:
                                size_obj = (
                                    ItemVariantSize.objects.select_for_update().get(
                                        item_variant=order_item.variant, size=size
                                    )
                                )
                            except ItemVariantSize.DoesNotExist:
                                transaction.set_rollback(True)
                                return Response(
                                    {
                                        "error": f"Size {size} not found for this variant"
                                    },
                                    status=status.HTTP_400_BAD_REQUEST,
                                )

                            if size_obj.stock < new_quantity:
                                transaction.set_rollback(True)
                                return Response(
                                    {"error": f"Insufficient stock in {size}"},
                                    status=status.HTTP_400_BAD_REQUEST,
                                )

                        for size in required_sizes:
                            ItemVariantSize.objects.filter(
                                item_variant=order_item.variant, size=size
                            ).update(
                                stock=F("stock") - new_quantity,
                                stock_updated_at=timezone.now(),
                            )

                    order_item.quantity = new_quantity
                    order_item.size_group = new_size_group

                    OrderLog.objects.create(
                        order=order,
                        action="ORDER_EDITED",
                        details={
                            "item_id": order_item.id,
                            "item_name": order_item.item_name,
                            "old_quantity": old_quantity,
                            "new_quantity": new_quantity,
                            "old_size_group": old_size_group,
                            "new_size_group": new_size_group,
                        },
                        performed_by=request.user,
                    )

                    order_item.save()

        return super().update(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        order_item = self.get_object()
        order = order_item.order
        if order.status != "DRAFT":
            return super().destroy(request, *args, **kwargs)
        if not _is_creator(request.user, order):
            return Response(
                {"error": "You can only edit your own draft orders"},
                status=status.HTTP_403_FORBIDDEN,
            )
        with transaction.atomic():
            locked_order = Order.objects.select_for_update().get(pk=order.pk)
            locked_item = OrderItem.objects.select_for_update().get(
                pk=order_item.pk, order=locked_order
            )
            _return_reserved_stock_for_item(locked_item)
            locked_item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    @extend_schema(summary="List unpacked items from PENDING orders")
    @action(detail=False, methods=["get"], url_path="unpacked")
    def unpacked(self, request):
        qs = (
            self.get_queryset()
            .filter(packed_quantity=0, order__status="PENDING")
            .select_related("variant")
            .order_by("-id")
        )
        serializer = UnpackedOrderItemSerializer(qs, many=True, context={"request": request})
        return Response(serializer.data)
