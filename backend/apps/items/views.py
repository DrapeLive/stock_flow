from rest_framework.viewsets import ModelViewSet
from .models import Item
from .serializers import ItemSerializer
from apps.accounts.permissions import IsAdmin
from rest_framework.permissions import IsAuthenticated

class ItemViewSet(ModelViewSet):
    queryset = Item.objects.all()
    serializer_class = ItemSerializer

    def get_permissions(self):
        if self.request.method in ['POST', 'PUT', 'PATCH', 'DELETE']:
            return [IsAdmin()]
        return [IsAuthenticated()]