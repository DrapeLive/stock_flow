from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.decorators import action
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
from apps.orders.models import Order

from .models import Agent, AgentItem
from .serializers import AgentItemListSerializer, AgentSerializer


class AgentViewSet(ModelViewSet):
    serializer_class = AgentSerializer
    permission_classes = [IsAdminOrSelfAgent]

    def get_queryset(self):
        user = self.request.user

        if user.role == "ADMIN":
            return Agent.objects.filter(is_active=True)

        return Agent.objects.filter(user=user, is_active=True)

    @action(detail=True, methods=["get"])
    def delete_info(self, request, pk=None):
        agent = self.get_object()
        customers_count = agent.customers.count()
        orders_count = Order.objects.filter(agent=agent).count()
        other_agents = Agent.objects.filter(is_active=True).exclude(id=agent.id)
        transferable_agents = [
            {"id": a.id, "name": a.user.username} for a in other_agents
        ]
        return Response(
            {
                "customers_count": customers_count,
                "orders_count": orders_count,
                "transferable_agents": transferable_agents,
            }
        )

    def destroy(self, request, *args, **kwargs):
        pin_error = check_admin_pin(request)
        if pin_error:
            return pin_error

        agent = self.get_object()
        action = request.data.get("action", "deactivate")

        if action == "transfer":
            transfer_to_id = request.data.get("transfer_to_id")
            if not transfer_to_id:
                return Response(
                    {"error": "transfer_to_id is required for transfer action."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            try:
                target_agent = Agent.objects.get(id=transfer_to_id, is_active=True)
            except Agent.DoesNotExist:
                return Response(
                    {"error": "Target agent not found."},
                    status=status.HTTP_404_NOT_FOUND,
                )

            agent.customers.all().update(agent=target_agent)
            agent.hard_delete()
            return Response(status=status.HTTP_204_NO_CONTENT)

        agent.soft_delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


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
            existing_qs = agent.assigned_items.filter(item__type=biz)
        else:
            existing_qs = agent.assigned_items.all()

        existing_item_ids = set(existing_qs.values_list("item_id", flat=True))
        incoming_item_ids = set(item_ids)

        ids_to_remove = existing_item_ids - incoming_item_ids
        if ids_to_remove:
            agent.assigned_items.filter(item_id__in=ids_to_remove).delete()

        ids_to_add = incoming_item_ids - existing_item_ids

        assigned_count = 0
        for item_id in ids_to_add:
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
                print(assigned_count)
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
