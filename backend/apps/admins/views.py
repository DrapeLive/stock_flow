from rest_framework.viewsets import ModelViewSet
from apps.accounts.permissions import IsAdmin
from apps.accounts.models import User
from .serializers import AdminSerializer

class AdminViewSet(ModelViewSet):
    queryset = User.objects.filter(role='ADMIN')
    serializer_class = AdminSerializer
    permission_classes = [IsAdmin]
