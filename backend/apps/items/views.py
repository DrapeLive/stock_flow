import os
from datetime import timedelta

from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet

from apps.accounts.permissions import IsAdmin, admin_business
from apps.orders.models import OrderItem
from apps.orders.utils import SIZE_MAPPING

from .models import Item, ItemVariant, ItemVariantSize
from .serializers import (
    CreateItemSerializer,
    ItemSerializer,
    ItemVariantSerializer,
    UpdateItemSerializer,
)

ITEM_CREATION_SIZES_BY_TYPE = {
    "gents": [
        "S,M,L,XL,XXL",
        "S,M,L,XL",
        "M,L,XL,XXL",
        "M,L,XL",
    ],
    "kids": [
        "20-24",
        "26-36",
        "38",
    ],
}

ORDER_CREATION_SIZES_BY_TYPE = {
    "gents": [
        "S,M,L,XL,XXL",
        "S,M,L,XL",
        "M,L,XL,XXL",
        "M,L,XL",
    ],
    "kids": [
        "20-38",
        "26-38",
        "32-38",
        "20-36",
        "26-36",
        "20-30",
        "32-36",
    ],
}


def get_agent_reservation_boost(user):
    """Return {(variant_id, size): qty} the agent can additionally see as available
    because of their currently-EDITING orders."""
    boost = {}
    if not hasattr(user, "role") or user.role != "AGENT":
        return boost

    from apps.orders.models import Order

    editing_orders = Order.objects.filter(agent__user=user, status="EDITING")
    for order in editing_orders:
        for snap in order.reservation_snapshot:
            item_type = snap["item_type"]
            if item_type not in SIZE_MAPPING:
                continue
            size_group = snap["size_group"]
            if size_group not in SIZE_MAPPING[item_type]:
                continue
            variant_id = snap["variant_id"]
            qty = snap["quantity"]
            for size in SIZE_MAPPING[item_type][size_group]:
                key = (variant_id, size)
                boost[key] = boost.get(key, 0) + qty
    return boost


def filter_items_by_business(qs, user):
    biz = admin_business(user)
    return qs.filter(type=biz) if biz else qs


class ItemViewSet(ModelViewSet):
    queryset = Item.objects.prefetch_related("variants__sizes").all()
    serializer_class = ItemSerializer

    def get_permissions(self):
        if self.request.method in ["POST", "PUT", "PATCH", "DELETE"]:
            return [IsAdmin()]
        return [IsAuthenticated()]

    def get_queryset(self):
        cutoff = timezone.now() - timedelta(days=30)
        return (
            filter_items_by_business(
                Item.objects.prefetch_related("variants__sizes"),
                self.request.user,
            )
            .filter(is_deleted=False)
            .exclude(out_of_stock_since__isnull=False, out_of_stock_since__lte=cutoff)
        )

    def get_serializer_class(self):
        if self.action == "create":
            return CreateItemSerializer
        if self.action in ["update", "partial_update"]:
            return UpdateItemSerializer
        return ItemSerializer

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()

        for variant in instance.variants.all():
            if variant.image:
                is_referenced = OrderItem.objects.filter(variant=variant).exists()
                if not is_referenced:
                    if variant.image.path and os.path.exists(variant.image.path):
                        os.remove(variant.image.path)

        instance.is_deleted = True
        instance.save()
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=False, methods=["get"], url_path="stock-list")
    def get_stock_list(self, request):
        items = filter_items_by_business(
            Item.objects.prefetch_related("variants__sizes"),
            request.user,
        ).filter(is_deleted=False)

        boost = get_agent_reservation_boost(request.user)

        result = []
        for item in items:
            variants = []
            for variant in item.variants.all():
                sizes = [
                    {
                        "size": s.size,
                        "stock": s.stock + boost.get((variant.id, s.size), 0),
                    }
                    for s in variant.sizes.all()
                ]
                variants.append(
                    {
                        "id": variant.id,
                        "qr_code": str(variant.qr_code) if variant.qr_code else None,
                        "image": request.build_absolute_uri(variant.image.url)
                        if variant.image
                        else None,
                        "sizes": sizes,
                        "total_stock": sum(s["stock"] for s in sizes),
                    }
                )

            result.append(
                {
                    "id": item.id,
                    "name": item.name,
                    "type": item.type,
                    "price": str(item.price),
                    "image": request.build_absolute_uri(item.variants.first().image.url)
                    if item.variants.exists() and item.variants.first().image
                    else None,
                    "variants": variants,
                }
            )

        return Response(result)

    @action(detail=False, methods=["get"], url_path="by-qr")
    def get_by_qr(self, request):
        qr_code = request.query_params.get("qr_code")
        qr_code = qr_code.strip()

        if len(qr_code) > 255 or "/" in qr_code:
            return Response({"error": "No such item with this QR exists"}, status=400)

        try:
            variant = (
                ItemVariant.objects.select_related("item")
                .prefetch_related("sizes")
                .get(qr_code=qr_code, item__is_deleted=False)
            )
        except Exception:
            return Response({"error": "Invalid QR code"}, status=400)

        try:
            variant = (
                ItemVariant.objects.select_related("item")
                .prefetch_related("sizes")
                .get(qr_code=qr_code, item__is_deleted=False)
            )
        except ItemVariant.DoesNotExist:
            return Response({"error": "Variant not found"}, status=404)

        biz = admin_business(request.user)
        if biz and variant.item.type != biz:
            return Response({"error": "Not found"}, status=404)

        item = variant.item
        variants = item.variants.prefetch_related("sizes").all()

        boost = get_agent_reservation_boost(request.user)

        response_variants = []
        for v in variants:
            variant_data = {
                "id": v.id,
                "qr_code": v.qr_code,
                "image": request.build_absolute_uri(v.image.url) if v.image else None,
                "sizes": [
                    {
                        "id": s.id,
                        "size": s.size,
                        "stock": s.stock + boost.get((v.id, s.size), 0),
                    }
                    for s in v.sizes.all()
                ],
            }
            response_variants.append(variant_data)

        return Response(
            {
                "id": item.id,
                "name": item.name,
                "price": item.price,
                "type": item.type,
                "description": item.description,
                "variants": response_variants,
                "matched_variant_id": variant.id,
            }
        )

    @action(detail=False, methods=["get"], url_path="archived")
    def get_archived(self, request):
        cutoff = timezone.now() - timedelta(days=30)
        items = filter_items_by_business(
            Item.objects.prefetch_related("variants__sizes"),
            request.user,
        ).filter(
            is_deleted=False,
            out_of_stock_since__isnull=False,
            out_of_stock_since__lte=cutoff,
        )
        serializer = self.get_serializer(items, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"], url_path="by-qr/out-of-stock")
    def check_out_of_stock(self, request):
        qr_code = request.query_params.get("qr_code", "").strip()
        if not qr_code or len(qr_code) > 255 or "/" in qr_code:
            return Response({"error": "Invalid QR code"}, status=400)

        try:
            variant = (
                ItemVariant.objects.select_related("item")
                .prefetch_related("sizes")
                .get(qr_code=qr_code, item__is_deleted=False)
            )
        except ItemVariant.DoesNotExist:
            return Response({"error": "Variant not found"}, status=404)

        biz = admin_business(request.user)
        if biz and variant.item.type != biz:
            return Response({"error": "Not found"}, status=404)

        item = variant.item
        item_type = item.type
        boost = get_agent_reservation_boost(request.user)

        # Build a flat stock map: { size: total_stock } across all variants
        stock_map: dict[str, int] = {}
        for v in item.variants.prefetch_related("sizes").all():
            for s in v.sizes.all():
                effective = s.stock + boost.get((v.id, s.size), 0)
                stock_map[s.size] = stock_map.get(s.size, 0) + effective

        size_groups = ORDER_CREATION_SIZES_BY_TYPE.get(item_type, [])

        group_stock = {}
        for group in size_groups:
            members = SIZE_MAPPING[item_type][group]
            group_stock[group] = min(stock_map.get(m, 0) for m in members)

        out_of_stock = all(v == 0 for v in group_stock.values())

        return Response(
            {
                "out_of_stock": out_of_stock,
                "group_stock": group_stock,
            }
        )


class ItemVariantViewSet(ModelViewSet):
    queryset = (
        ItemVariant.objects.prefetch_related("sizes")
        .filter(item__is_deleted=False)
        .all()
    )
    serializer_class = ItemVariantSerializer

    def get_permissions(self):
        if self.request.method in ["POST", "PUT", "PATCH", "DELETE"]:
            return [IsAdmin()]
        return [IsAuthenticated()]

    @action(detail=False, methods=["get"], url_path="all")
    def get_all_variants(self, request):
        variants = filter_items_by_business(
            ItemVariant.objects.select_related("item").prefetch_related("sizes"),
            request.user,
        ).filter(item__is_deleted=False)

        boost = get_agent_reservation_boost(request.user)

        result = []
        for variant in variants:
            sizes_with_boost = [
                {"size": s.size, "stock": s.stock + boost.get((variant.id, s.size), 0)}
                for s in variant.sizes.all()
            ]
            total_stock = sum(s["stock"] for s in sizes_with_boost)
            unique_sizes = list(set(s["size"] for s in sizes_with_boost))

            result.append(
                {
                    "id": variant.id,
                    "item_id": variant.item.id,
                    "item_name": variant.item.name,
                    "item_type": variant.item.type,
                    "item_price": str(variant.item.price),
                    "qr_code": str(variant.qr_code) if variant.qr_code else None,
                    "image": request.build_absolute_uri(variant.image.url)
                    if variant.image
                    else None,
                    "sizes": sizes_with_boost,
                    "total_stock": total_stock,
                    "unique_sizes": unique_sizes,
                }
            )

        return Response(result)


class SizeRangesAPIView(APIView):
    def get(self, request):
        return Response(
            {
                "item_creation_sizes_by_type": ITEM_CREATION_SIZES_BY_TYPE,
                "order_creation_sizes_by_type": ORDER_CREATION_SIZES_BY_TYPE,
            }
        )
