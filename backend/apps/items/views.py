
from rest_framework.viewsets import ModelViewSet, ViewSet
from .models import Item, ItemVariant
from .serializers import ItemSerializer, ItemVariantSerializer
from apps.accounts.permissions import IsAdmin
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.shortcuts import get_object_or_404
from rest_framework.decorators import action

class ItemViewSet(ModelViewSet):
    queryset = Item.objects.all()
    serializer_class = ItemSerializer

    def get_permissions(self):
        if self.request.method in ['POST', 'PUT', 'PATCH', 'DELETE']:
            return [IsAdmin()]
        return [IsAuthenticated()]

    @action(detail=False, methods=['get'], url_path='by-qr')
    def get_by_qr(self, request):

        qr_code = request.query_params.get('qr_code')

        if not qr_code:
            return Response(
                {"error": "qr_code query parameter is required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        item = get_object_or_404(
            Item.objects.prefetch_related("variants", "sizes"),
            qr_code=qr_code
        )

        serializer = self.get_serializer(item)

        return Response(serializer.data)

class ItemVariantViewSet(ModelViewSet):
    queryset = ItemVariant.objects.all()
    serializer_class = ItemVariantSerializer

    def get_permissions(self):
        if self.request.method in ['POST', 'PUT', 'PATCH', 'DELETE']:
            return [IsAdmin()]
        return [IsAuthenticated()]

# class ItemSizeViewSet(ModelViewSet):
#     queryset = ItemSize.objects.all()
#     serializer_class = ItemSizeSerializer
#
#     def get_permissions(self):
#         if self.request.method in ['POST', 'PUT', 'PATCH', 'DELETE']:
#             return [IsAdmin()]
#         return [IsAuthenticated()]

