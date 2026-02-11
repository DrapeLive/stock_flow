from rest_framework.viewsets import ModelViewSet, ViewSet
from .models import Item, ItemVariant, ItemSize
from .serializers import ItemSerializer, ItemVariantSerializer,ItemSizeSerializer
from apps.accounts.permissions import IsAdmin
from rest_framework.permissions import IsAuthenticated


class ItemViewSet(ModelViewSet):
    queryset = Item.objects.all()
    serializer_class = ItemSerializer

    def get_permissions(self):
        if self.request.method in ['POST', 'PUT', 'PATCH', 'DELETE']:
            return [IsAdmin()]
        return [IsAuthenticated()]

class ItemVariantViewSet(ModelViewSet):
    queryset = ItemVariant.objects.all()
    serializer_class = ItemVariantSerializer

    def get_permissions(self):
        if self.request.method in ['POST', 'PUT', 'PATCH', 'DELETE']:
            return [IsAdmin()]
        return [IsAuthenticated()]

class ItemSizeViewSet(ModelViewSet):
    queryset = ItemSize.objects.all()
    serializer_class = ItemSizeSerializer

    def get_permissions(self):
        if self.request.method in ['POST', 'PUT', 'PATCH', 'DELETE']:
            return [IsAdmin()]
        return [IsAuthenticated()]

