from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet

from apps.accounts.permissions import (
    IsAdminOrSelfAgent,
    admin_business,
    check_admin_pin,
)
from apps.items.models import Item
from apps.notification.tasks import send_push_to_user

from .models import Agent, AgentItem
from .serializers import AgentItemListSerializer, AgentSerializer


class AgentViewSet(ModelViewSet):
    serializer_class = AgentSerializer
    permission_classes = [IsAdminOrSelfAgent]

    def get_queryset(self):
        user = self.request.user

        if user.role == "ADMIN":
            return Agent.objects.all()

        return Agent.objects.filter(user=user)

    def destroy(self, request, *args, **kwargs):
        pin_error = check_admin_pin(request)
        if pin_error:
            return pin_error
        return super().destroy(request, *args, **kwargs)


class AgentDetail(APIView):
    def get(self, request, user_id):
        agent = get_object_or_404(Agent, user_id=user_id)
        serializer = AgentSerializer(agent, context={"request": request})
        return Response(serializer.data)


class AgentItemsView(APIView):
    permission_classes = [IsAdminOrSelfAgent]

    def get(self, request, agent_id):
        agent = get_object_or_404(Agent, id=agent_id)
        biz = admin_business(request.user)
        qs = agent.assigned_items.select_related("item").prefetch_related(
            "item__variants__sizes"
        )
        if biz:
            qs = qs.filter(item__type=biz)
        items = [ai.item for ai in qs.all()]
        result = [AgentItemListSerializer.from_item(item, request) for item in items]
        return Response(result)

    def post(self, request, agent_id):
        agent = get_object_or_404(Agent, id=agent_id)
        item_ids = request.data.get("item_ids", [])

        if not isinstance(item_ids, list):
            return Response(
                {"error": "item_ids must be a list"}, status=status.HTTP_400_BAD_REQUEST
            )

        biz = admin_business(request.user)
        if biz:
            agent.assigned_items.filter(item__type=biz).delete()
        else:
            agent.assigned_items.all().delete()

        assigned_count = 0
        for item_id in item_ids:
            try:
                if biz:
                    item = Item.objects.get(id=item_id, type=biz)
                else:
                    item = Item.objects.get(id=item_id)
                AgentItem.objects.create(agent=agent, item=item)
                assigned_count += 1
            except Item.DoesNotExist:
                pass

        items = [
            ai.item
            for ai in agent.assigned_items.select_related("item")
            .prefetch_related("item__variants__sizes")
            .all()
        ]
        result = [AgentItemListSerializer.from_item(item, request) for item in items]

        if assigned_count > 0:
            try:
                send_push_to_user.delay(
                    agent.user_id,
                    "Items Assigned",
                    f"{assigned_count} item{'s' if assigned_count > 1 else ''} have been assigned to you",
                )
            except Exception as e:
                print("Failed to queue notification:", str(e))
        return Response(result)


class AgentItemDetailView(APIView):
    permission_classes = [IsAdminOrSelfAgent]

    def delete(self, request, agent_id, item_id):
        agent = get_object_or_404(Agent, id=agent_id)
        agent_item = get_object_or_404(AgentItem, agent=agent, item_id=item_id)

        biz = admin_business(request.user)
        if biz and agent_item.item.type != biz:
            return Response({"error": "Not found"}, status=404)

        agent_item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
