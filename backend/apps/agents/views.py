from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet
from .models import Agent
from .serializers import AgentSerializer
from apps.accounts.permissions import IsAdminOrSelfAgent
from django.shortcuts import get_object_or_404


class AgentViewSet(ModelViewSet):
    serializer_class = AgentSerializer
    permission_classes = [IsAdminOrSelfAgent]

    def get_queryset(self):
        user = self.request.user

        if user.role == 'ADMIN':
            return Agent.objects.all()

        return Agent.objects.filter(user=user)

class AgentDetail(APIView):
    def get(self, request, user_id):
        agent = get_object_or_404(Agent, user_id=user_id)
        serializer = AgentSerializer(agent)
        return Response(serializer.data)