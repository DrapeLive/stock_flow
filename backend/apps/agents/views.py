from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet
from rest_framework.permissions import IsAuthenticated
from .models import Agent, AgentItem
from .serializers import AgentSerializer, AgentItemListSerializer
from apps.accounts.permissions import IsAdminOrSelfAgent
from django.shortcuts import get_object_or_404
from apps.items.models import Item


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
        serializer = AgentSerializer(agent, context={'request': request})
        return Response(serializer.data)


class AgentItemsView(APIView):
    permission_classes = [IsAdminOrSelfAgent]

    def get(self, request, agent_id):
        agent = get_object_or_404(Agent, id=agent_id)
        items = [ai.item for ai in agent.assigned_items.select_related('item').prefetch_related('item__variants__sizes').all()]
        result = [
            AgentItemListSerializer.from_item(item, request)
            for item in items
        ]
        return Response(result)

    def post(self, request, agent_id):
        agent = get_object_or_404(Agent, id=agent_id)
        item_ids = request.data.get('item_ids', [])

        if not isinstance(item_ids, list):
            return Response(
                {'error': 'item_ids must be a list'},
                status=status.HTTP_400_BAD_REQUEST
            )

        agent.assigned_items.all().delete()

        for item_id in item_ids:
            try:
                item = Item.objects.get(id=item_id)
                AgentItem.objects.create(agent=agent, item=item)
            except Item.DoesNotExist:
                pass

        items = [ai.item for ai in agent.assigned_items.select_related('item').prefetch_related('item__variants__sizes').all()]
        result = [
            AgentItemListSerializer.from_item(item, request)
            for item in items
        ]
        return Response(result)


class AgentItemDetailView(APIView):
    permission_classes = [IsAdminOrSelfAgent]

    def delete(self, request, agent_id, item_id):
        agent = get_object_or_404(Agent, id=agent_id)
        agent_item = get_object_or_404(AgentItem, agent=agent, item_id=item_id)
        agent_item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
