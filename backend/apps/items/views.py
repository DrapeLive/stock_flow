from collections import defaultdict

from rest_framework.viewsets import ModelViewSet
from .models import Item, ItemVariant
from .serializers import ItemSerializer, ItemVariantSerializer
from apps.accounts.permissions import IsAdmin
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from rest_framework.decorators import action
import os

class ItemViewSet(ModelViewSet):
    queryset = Item.objects.prefetch_related("variants").all()
    serializer_class = ItemSerializer

    def get_permissions(self):
        if self.request.method in ["POST", "PUT", "PATCH", "DELETE"]:
            return [IsAdmin()]
        return [IsAuthenticated()]

    @action(detail=False, methods=["get"], url_path="by-qr")
    def get_by_qr(self, request):
        qr_code = request.query_params.get("qr_code")

        if not qr_code:
            return Response({"error": "qr_code query parameter is required"}, status=400)

        variant = get_object_or_404(ItemVariant, qr_code=qr_code)
        item = variant.item

        variants = item.variants.all()

        grouped = defaultdict(lambda: {"image": None, "sizes": []})

        for v in variants:
            filename = os.path.basename(v.image.name)
            base = filename.split("_")[0]

            grouped[base]["image"] = request.build_absolute_uri(v.image.url)

            grouped[base]["sizes"].append({
                "variant_id": v.id,
                "size": v.size,
                "stock": v.stock,
                "qr_code": str(v.qr_code)
            })

        response_variants = list(grouped.values())

        return Response({
            "id": item.id,
            "name": item.name,
            "price": item.price,
            "type": item.type,
            "description": item.description,
            "variants": response_variants
        })

class ItemVariantViewSet(ModelViewSet):
    queryset = ItemVariant.objects.all()
    serializer_class = ItemVariantSerializer

    def get_permissions(self):
        if self.request.method in ["POST", "PUT", "PATCH", "DELETE"]:
            return [IsAdmin()]
        return [IsAuthenticated()]
