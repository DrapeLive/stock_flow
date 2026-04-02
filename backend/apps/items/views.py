from rest_framework.viewsets import ModelViewSet
from .models import Item, ItemVariant, ItemVariantSize
from .serializers import ItemSerializer, ItemVariantSerializer, CreateItemSerializer, UpdateItemSerializer
from apps.accounts.permissions import IsAdmin
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from rest_framework.decorators import action
from rest_framework import status


class ItemViewSet(ModelViewSet):
    queryset = Item.objects.prefetch_related("variants__sizes").all()
    serializer_class = ItemSerializer

    def get_permissions(self):
        if self.request.method in ["POST", "PUT", "PATCH", "DELETE"]:
            return [IsAdmin()]
        return [IsAuthenticated()]

    def get_serializer_class(self):
        if self.action == 'create':
            return CreateItemSerializer
        if self.action in ['update', 'partial_update']:
            return UpdateItemSerializer
        return ItemSerializer

    @action(detail=False, methods=["get"], url_path="by-qr")
    def get_by_qr(self, request):
        qr_code = request.query_params.get("qr_code")

        if not qr_code:
            return Response({"error": "qr_code query parameter is required"}, status=400)

        try:
            variant = ItemVariant.objects.select_related('item').prefetch_related('sizes').get(qr_code=qr_code)
        except ItemVariant.DoesNotExist:
            return Response({"error": "Variant not found"}, status=404)

        item = variant.item
        variants = item.variants.prefetch_related('sizes').all()

        response_variants = []
        for v in variants:
            variant_data = {
                "id": v.id,
                "image": request.build_absolute_uri(v.image.url) if v.image else None,
                "sizes": [
                    {
                        "id": s.id,
                        "size": s.size,
                        "stock": s.stock
                    }
                    for s in v.sizes.all()
                ]
            }
            response_variants.append(variant_data)

        return Response({
            "id": item.id,
            "name": item.name,
            "price": item.price,
            "type": item.type,
            "description": item.description,
            "variants": response_variants,
            "matched_variant_id": variant.id
        })


class ItemVariantViewSet(ModelViewSet):
    queryset = ItemVariant.objects.prefetch_related('sizes').all()
    serializer_class = ItemVariantSerializer

    def get_permissions(self):
        if self.request.method in ["POST", "PUT", "PATCH", "DELETE"]:
            return [IsAdmin()]
        return [IsAuthenticated()]
