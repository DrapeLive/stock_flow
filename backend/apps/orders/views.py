from django.db import transaction
from django.shortcuts import get_object_or_404
from django.db.models import F, Q
from django.utils import timezone

from rest_framework.viewsets import ModelViewSet
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated

from apps.accounts.permissions import IsAgent, admin_business
from apps.agents.models import AgentItem
from apps.items.models import ItemVariantSize
from apps.orders.models import Order, OrderItem, OrderLog
from apps.orders.serializers import AddOrderItemSerializer, InvoiceSerializer, OrderItemSerializer, OrderSerializer, get_piece_count
from apps.orders.utils import SIZE_MAPPING


class OrderPagination(PageNumberPagination):
    page_size = 50
    page_size_query_param = 'page_size'
    max_page_size = 200


def _build_snapshot(order):
    """Build a list of dicts representing all OrderItems for reservation snapshot."""
    return [
        {
            'item_id': oi.item_id,
            'variant_id': oi.variant_id,
            'size_group': oi.size_group,
            'item_type': oi.item_type,
            'item_name': oi.item_name,
            'item_price': str(oi.item_price),
            'variant_image': oi.variant_image,
            'size': oi.size,
            'quantity': oi.quantity,
        }
        for oi in order.items.all()
    ]


def _revert_edit(order):
    """Restore OrderItems from reservation_snapshot and set status back to PENDING."""
    with transaction.atomic():
        order.items.all().delete()
        for snap in order.reservation_snapshot:
            OrderItem.objects.create(
                order=order,
                item_id=snap['item_id'],
                variant_id=snap['variant_id'],
                size_group=snap['size_group'],
                item_type=snap['item_type'],
                item_name=snap['item_name'],
                item_price=snap['item_price'],
                variant_image=snap.get('variant_image'),
                size=snap.get('size', ''),
                quantity=snap['quantity'],
            )
        order.reservation_snapshot = []
        order.editing_started_at = None
        order.status = 'PENDING'
        order.save()


class PlaceOrderView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, order_id):
        order = get_object_or_404(Order, id=order_id)

        if order.status != 'DRAFT':
            return Response(
                {"error": "Only DRAFT orders can be placed"},
                status=status.HTTP_400_BAD_REQUEST
            )

        if not order.items.exists():
            return Response(
                {"error": "Cannot place an empty order"},
                status=status.HTTP_400_BAD_REQUEST
            )

        out_of_stock_items = []

        with transaction.atomic():
            for order_item in order.items.select_related('item', 'variant'):
                if order_item.item is None or order_item.item.is_deleted:
                    continue

                item_type = order_item.item.type
                required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

                for size in required_sizes:
                    try:
                        size_obj = ItemVariantSize.objects.select_for_update().get(
                            item_variant=order_item.variant,
                            size=size
                        )
                    except ItemVariantSize.DoesNotExist:
                        out_of_stock_items.append({
                            "item_name": order_item.item_name,
                            "size_group": order_item.size_group,
                            "size": size,
                            "required": order_item.quantity,
                            "available": 0,
                            "order_item_id": order_item.id
                        })
                        continue

                    if size_obj.stock < order_item.quantity:
                        out_of_stock_items.append({
                            "item_name": order_item.item_name,
                            "size_group": order_item.size_group,
                            "size": size,
                            "required": order_item.quantity,
                            "available": size_obj.stock,
                            "order_item_id": order_item.id
                        })

            if out_of_stock_items:
                return Response(
                    {
                        "error": "Some items are no longer available. Another agent may have placed an order.",
                        "out_of_stock_items": out_of_stock_items
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            for order_item in order.items.select_related('item', 'variant'):
                if order_item.item is None or order_item.item.is_deleted:
                    continue

                item_type = order_item.item.type
                required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

                for size in required_sizes:
                    ItemVariantSize.objects.filter(
                        item_variant=order_item.variant,
                        size=size
                    ).update(stock=F('stock') - order_item.quantity)

            order.status = 'PENDING'
            order.save()

        return Response({
            "message": "Order placed successfully",
            "order_id": order.id
        })


def return_stock_for_item(order_item):
    """Return stock to warehouse for an order item."""
    if order_item.item is None or order_item.item.is_deleted:
        return

    item_type = order_item.item.type
    required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

    for size in required_sizes:
        ItemVariantSize.objects.filter(
            item_variant=order_item.variant,
            size=size
        ).update(stock=F('stock') + order_item.quantity)


class StartEditView(APIView):
    permission_classes = [IsAgent]

    def post(self, request, order_id):
        order = get_object_or_404(Order, id=order_id)

        if order.status != 'PENDING':
            return Response(
                {"error": "Only PENDING orders can be edited"},
                status=status.HTTP_400_BAD_REQUEST
            )

        if order.agent.user != request.user:
            return Response({"error": "Unauthorized"}, status=403)

        order.reservation_snapshot = _build_snapshot(order)
        order.editing_started_at = timezone.now()
        order.status = 'EDITING'
        order.save()

        OrderLog.objects.create(
            order=order,
            action='EDIT_STARTED',
            details={'items_count': len(order.reservation_snapshot)},
            performed_by=request.user,
        )

        return Response({"message": "Edit started"})


class SaveEditView(APIView):
    permission_classes = [IsAgent]

    def post(self, request, order_id):
        order = get_object_or_404(Order, id=order_id)

        if order.status != 'EDITING':
            return Response(
                {"error": "Order is not in editing mode"},
                status=status.HTTP_400_BAD_REQUEST
            )

        if order.agent.user != request.user:
            return Response({"error": "Unauthorized"}, status=403)

        with transaction.atomic():
            for snap in order.reservation_snapshot:
                item_type = snap['item_type']
                required_sizes = SIZE_MAPPING[item_type][snap['size_group']]
                for size in required_sizes:
                    ItemVariantSize.objects.filter(
                        item_variant_id=snap['variant_id'],
                        size=size
                    ).update(stock=F('stock') + snap['quantity'])

            out_of_stock_items = []
            for order_item in order.items.select_related('item', 'variant'):
                if order_item.item is None or order_item.item.is_deleted:
                    continue

                item_type = order_item.item.type
                required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

                for size in required_sizes:
                    try:
                        size_obj = ItemVariantSize.objects.select_for_update().get(
                            item_variant=order_item.variant,
                            size=size
                        )
                    except ItemVariantSize.DoesNotExist:
                        out_of_stock_items.append({
                            "item_name": order_item.item_name,
                            "size_group": order_item.size_group,
                            "size": size,
                            "required": order_item.quantity,
                            "available": 0,
                            "order_item_id": order_item.id
                        })
                        continue

                    if size_obj.stock < order_item.quantity:
                        out_of_stock_items.append({
                            "item_name": order_item.item_name,
                            "size_group": order_item.size_group,
                            "size": size,
                            "required": order_item.quantity,
                            "available": size_obj.stock,
                            "order_item_id": order_item.id
                        })

            if out_of_stock_items:
                return Response(
                    {
                        "error": "Some items are no longer available. Another agent may have placed an order.",
                        "out_of_stock_items": out_of_stock_items
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            for order_item in order.items.select_related('item', 'variant'):
                if order_item.item is None or order_item.item.is_deleted:
                    continue

                item_type = order_item.item.type
                required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

                for size in required_sizes:
                    ItemVariantSize.objects.filter(
                        item_variant=order_item.variant,
                        size=size
                    ).update(stock=F('stock') - order_item.quantity)

            order.reservation_snapshot = []
            order.editing_started_at = None
            order.status = 'PENDING'
            order.save()

        OrderLog.objects.create(
            order=order,
            action='EDIT_SAVED',
            details={'items_count': order.items.count()},
            performed_by=request.user,
        )

        return Response({
            "message": "Order saved successfully",
            "order_id": order.id
        })


class OrderViewSet(ModelViewSet):

    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = OrderPagination

    def get_queryset(self):

        if self.action == "list":
            from django.utils import timezone
            from datetime import timedelta

            cutoff = timezone.now() - timedelta(minutes=30)
            Order.objects.filter(
                status='DRAFT',
                agent__user=self.request.user,
                created_at__lt=cutoff
            ).delete()

            stale_editing = Order.objects.filter(
                status='EDITING',
                agent__user=self.request.user,
                editing_started_at__lt=cutoff,
            )
            for o in stale_editing:
                _revert_edit(o)

        user = self.request.user

        qs = Order.objects.prefetch_related(
            "items__variant",
            "items__item"
        ).order_by('-created_at').exclude(status='DRAFT')  # newest first

        customer_id = self.request.query_params.get('customer')
        if customer_id:
            qs = qs.filter(customer_id=customer_id)

        from_date = self.request.query_params.get('from_date')
        if from_date:
            qs = qs.filter(created_at__date__gte=from_date)

        to_date = self.request.query_params.get('to_date')
        if to_date:
            qs = qs.filter(created_at__date__lte=to_date)

        agent_id = self.request.query_params.get('agent')
        if agent_id and user.role == "ADMIN":
            qs = qs.filter(agent_id=agent_id)

        statuses = self.request.query_params.getlist('status')

        if statuses:
            qs = qs.filter(status__in=[s.upper() for s in statuses])
        if user.role == "ADMIN":
            biz = admin_business(user)
            if biz:
                qs = qs.filter(items__item_type=biz).distinct()

            search = self.request.query_params.get('search')
            if search:
                qs = qs.filter(
                    Q(customer__name__icontains=search) |
                    Q(agent__user__username__icontains=search) |
                    Q(id__icontains=search)
                ).distinct()

            return qs

        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(
                Q(customer__name__icontains=search) |
                Q(agent__user__username__icontains=search) |
                Q(id__icontains=search)
            ).distinct()

        return qs.filter(agent__user=user)

    def perform_create(self, serializer):

        serializer.save(
            agent=self.request.user.agent
        )

    def destroy(self, request, pk=None):
        order = self.get_object()

        if order.status != 'DRAFT':
            with transaction.atomic():
                for order_item in order.items.select_related('item', 'variant'):
                    return_stock_for_item(order_item)

                OrderLog.objects.create(
                    order=order,
                    action='ORDER_DELETED',
                    details={
                        'customer': order.customer.name,
                        'items_count': order.items.count(),
                        'status': order.status
                    },
                    performed_by=request.user
                )

        order.delete()

        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=["post"], url_path="dispatch")
    def dispatch_order(self, request, pk=None):
        order = self.get_object()

        if order.status not in ['PENDING', 'PACKED']:
            return Response(
                {"error": "Only PENDING or PACKED orders can be dispatched"},
                status=status.HTTP_400_BAD_REQUEST
            )

        with transaction.atomic():
            for order_item in order.items.select_related('item', 'variant'):
                if order_item.item is None or order_item.item.is_deleted:
                    continue

                piece_count = get_piece_count(order_item.size_group, order_item.item_type or 'gents')
                packed_sets = (order_item.packed_quantity or 0) // piece_count if piece_count > 0 else 0
                unpacked_sets = order_item.quantity - packed_sets

                if unpacked_sets > 0:
                    item_type = order_item.item.type
                    required_sizes = SIZE_MAPPING[item_type][order_item.size_group]
                    for size in required_sizes:
                        ItemVariantSize.objects.filter(
                            item_variant=order_item.variant,
                            size=size
                        ).update(stock=F('stock') + unpacked_sets)

            OrderLog.objects.create(
                order=order,
                action='DISPATCHED',
                details={
                    'packed_items': sum(1 for i in order.items.all() if (i.packed_quantity or 0) > 0),
                    'total_items': order.items.count()
                },
                performed_by=request.user
            )

            order.status = 'DISPATCHED'
            order.save()

        return Response({"message": "Order dispatched successfully"})

    @action(detail=True, methods=["post"], url_path="cancel-edit")
    def cancel_edit(self, request, pk=None):
        order = self.get_object()

        if order.status != 'EDITING':
            return Response(
                {"error": "Order is not in editing mode"},
                status=status.HTTP_400_BAD_REQUEST
            )

        if order.agent.user != request.user:
            return Response({"error": "Unauthorized"}, status=403)

        _revert_edit(order)

        OrderLog.objects.create(
            order=order,
            action='EDIT_CANCELLED',
            details={},
            performed_by=request.user,
        )

        return Response({"message": "Edit cancelled"})

    @action(detail=False, methods=["get"], url_path="order-ids")
    def order_ids(self, request):
        """Return lightweight list of {id, status} for all orders (for unread count)."""
        user = request.user
        qs = Order.objects.all()

        if user.role == "ADMIN":
            biz = admin_business(user)
            if biz:
                qs = qs.filter(items__item_type=biz).distinct()
        else:
            qs = qs.filter(agent__user=user)

        qs = qs.values_list('id', 'status')
        return Response([{"id": oid, "status": stat} for oid, stat in qs])


class AddOrderItemView(APIView):

    permission_classes = [IsAgent]

    def post(self, request, order_id):

        serializer = AddOrderItemSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        order = get_object_or_404(Order, id=order_id)

        if order.status not in ('DRAFT', 'EDITING'):
            return Response(
                {"error": "Items can only be added to DRAFT or EDITING orders"},
                status=status.HTTP_400_BAD_REQUEST
            )

        agent = request.user.agent

        item = serializer.validated_data["item"]
        variant = serializer.validated_data["variant"]
        qty = serializer.validated_data["quantity"]
        size_group = serializer.validated_data["size_group"]

        if not AgentItem.objects.filter(agent=agent, item=item).exists():
            return Response(
                {"error": "This item is not assigned to you. Please contact admin for assignment."},
                status=status.HTTP_400_BAD_REQUEST
            )

        existing = order.items.first()
        if existing and existing.item_type != item.type:
            return Response(
                {"error": f"Order can only contain items of {existing.item_type} type"},
                status=status.HTTP_400_BAD_REQUEST
            )

        item_type = item.type

        if size_group not in SIZE_MAPPING[item_type]:
            return Response(
                {"error": "Invalid size group"},
                status=status.HTTP_400_BAD_REQUEST
            )


        with transaction.atomic():

            OrderItem.objects.create(
                order=order,
                item=item,
                variant=variant,
                size_group=size_group,
                item_type=item_type,
                item_name=serializer.validated_data["item_name"],
                item_price=serializer.validated_data["item_price"],
                variant_image=serializer.validated_data.get("variant_image"),
                size=serializer.validated_data.get("size", ""),
                quantity=qty
            )

        return Response(
            {"message": "Item added successfully"},
            status=status.HTTP_201_CREATED
        )


class DeleteOrderItemView(APIView):

    permission_classes = [IsAgent]

    def delete(self, request, order_id, item_id):

        order = get_object_or_404(Order, id=order_id)

        order_item = get_object_or_404(
            OrderItem,
            id=item_id,
            order=order
        )

        if order.status not in ('DRAFT', 'EDITING'):
            if order_item.item is not None and not order_item.item.is_deleted:
                item_type = order_item.item.type
                required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

                with transaction.atomic():

                    for size in required_sizes:
                        ItemVariantSize.objects.filter(
                            item_variant=order_item.variant,
                            size=size
                        ).update(stock=F('stock') + order_item.quantity)

                OrderLog.objects.create(
                    order=order,
                    action='ITEM_DELETED',
                    details={
                        'item_name': order_item.item_name,
                        'size_group': order_item.size_group,
                        'quantity': order_item.quantity,
                        'stock_returned': True
                    },
                    performed_by=request.user
                )
        else:
            OrderLog.objects.create(
                order=order,
                action='ITEM_DELETED',
                details={
                    'item_name': order_item.item_name,
                    'size_group': order_item.size_group,
                    'quantity': order_item.quantity,
                    'stock_returned': False
                },
                performed_by=request.user
            )

        order_item.delete()

        return Response(
            {"message": "Item Deleted Successfully"}
        )


class InvoiceView(APIView):

    permission_classes = [IsAuthenticated]

    def get(self, request, order_id):
        order = get_object_or_404(
            Order.objects.prefetch_related(
                "items__item__brand"
            ),
            id=order_id
        )

        biz = admin_business(request.user)
        if biz and not order.items.filter(item_type=biz).exists():
            return Response({"error": "Not found"}, status=404)

        serializer = InvoiceSerializer(order,context={'request': request})

        return Response(serializer.data)


class OrderLogsView(APIView):

    permission_classes = [IsAuthenticated]

    def get(self, request, order_id):
        order = get_object_or_404(Order, id=order_id)

        if request.user.role == 'ADMIN':
            biz = admin_business(request.user)
            if biz and not order.items.filter(item_type=biz).exists():
                return Response({"error": "Not found"}, status=404)
        elif order.agent.user != request.user:
            return Response({"error": "Unauthorized"}, status=403)

        logs = order.logs.all().order_by('-created_at')


        result = []
        for log in logs:
            user_name = None
            if log.performed_by:
                user_name = log.performed_by.username

            result.append({
                'id': log.id,
                'action': log.action,
                'details': log.details,
                'performed_by': user_name,
                'created_at': log.created_at.isoformat()
            })

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

        return qs.filter(
            order__agent__user=user
        )

    def update(self, request, *args, **kwargs):
        order_item = self.get_object()
        order = order_item.order

        if order.status not in ['DRAFT', 'EDITING', 'PENDING', 'PACKED']:
            return Response(
                {"error": "Cannot edit items in this order status"},
                status=status.HTTP_400_BAD_REQUEST
            )

        old_quantity = order_item.quantity
        old_size_group = order_item.size_group

        new_quantity = request.data.get('quantity', old_quantity)
        new_size_group = request.data.get('size_group', old_size_group)

        item_type = order_item.item_type
        if new_size_group not in SIZE_MAPPING.get(item_type, {}):
            return Response(
                {"error": "Invalid size group for this item type"},
                status=status.HTTP_400_BAD_REQUEST
            )

        if order.status == 'EDITING':
            order_item.quantity = new_quantity
            order_item.size_group = new_size_group
            order_item.save()
            return super().update(request, *args, **kwargs)

        if order.status != 'DRAFT':
            with transaction.atomic():
                if old_quantity != new_quantity or old_size_group != new_size_group:
                    return_stock_for_item(order_item)

                    if order_item.item:
                        item_type = order_item.item.type
                        required_sizes = SIZE_MAPPING[item_type][new_size_group]

                        for size in required_sizes:
                            try:
                                size_obj = ItemVariantSize.objects.select_for_update().get(
                                    item_variant=order_item.variant,
                                    size=size
                                )
                            except ItemVariantSize.DoesNotExist:
                                return Response(
                                    {"error": f"Size {size} not found for this variant"},
                                    status=status.HTTP_400_BAD_REQUEST
                                )

                            if size_obj.stock < new_quantity:
                                return Response(
                                    {"error": f"Insufficient stock in {size}"},
                                    status=status.HTTP_400_BAD_REQUEST
                                )

                        for size in required_sizes:
                            ItemVariantSize.objects.filter(
                                item_variant=order_item.variant,
                                size=size
                            ).update(stock=F('stock') - new_quantity)

                    order_item.quantity = new_quantity
                    order_item.size_group = new_size_group

                    OrderLog.objects.create(
                        order=order,
                        action='ORDER_EDITED',
                        details={
                            'item_id': order_item.id,
                            'item_name': order_item.item_name,
                            'old_quantity': old_quantity,
                            'new_quantity': new_quantity,
                            'old_size_group': old_size_group,
                            'new_size_group': new_size_group
                        },
                        performed_by=request.user
                    )

                    order_item.save()

        return super().update(request, *args, **kwargs)
