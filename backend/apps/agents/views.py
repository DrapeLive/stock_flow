from rest_framework.viewsets import ModelViewSet
from .models import Agent
from .serializers import AgentSerializer
from apps.accounts.permissions import IsAdmin

class AgentViewSet(ModelViewSet):
    queryset = Agent.objects.all()
    serializer_class = AgentSerializer
    permission_classes = [IsAdmin]