from rest_framework.viewsets import ModelViewSet
from .models import Agent
from .serializers import AgentSerializer
from apps.accounts.permissions import IsAdminOrSelfAgent


class AgentViewSet(ModelViewSet):
    serializer_class = AgentSerializer
    permission_classes = [IsAdminOrSelfAgent]

    def get_queryset(self):
        user = self.request.user

        if user.role == 'ADMIN':
            return Agent.objects.all()

        return Agent.objects.filter(user=user)