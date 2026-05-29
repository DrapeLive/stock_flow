from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet
from collections import defaultdict

from apps.accounts.permissions import (
    IsAdminOrSelfAgent,
    admin_business,
    check_admin_pin,
)
from apps.items.models import ItemVariant
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
            return Agent.objects.filter(is_active=True).order_by('-id')

        return Agent.objects.filter(user=user, is_active=True).order_by('-id')

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
        action_param = request.data.get("action", "deactivate")

        if action_param == "transfer":
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
        qs = (
            agent.assigned_items
            .select_related("variant__item")
            .prefetch_related("variant__sizes")
        )
        if biz:
            qs = qs.filter(variant__item__type=biz)
        qs = qs.order_by('-id')

        item_groups = defaultdict(list)
        for ai in qs:
            item_groups[ai.variant.item_id].append(ai)

        result = []
        for item_id, agent_items in item_groups.items():
            item_obj = agent_items[0].variant.item
            result.append(
                AgentItemListSerializer.from_assigned_variants(
                    item_obj, agent_items, request
                )
            )
        return Response(result)

    def post(self, request, agent_id):
        agent = get_object_or_404(Agent, id=agent_id)
        variant_ids = request.data.get("variant_ids", [])

        if not isinstance(variant_ids, list):
            return Response(
                {"error": "variant_ids must be a list"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        biz = admin_business(request.user)
        existing_qs = agent.assigned_items.all()
        existing_variant_ids = set(
            existing_qs.values_list("variant_id", flat=True)
        )
        incoming_variant_ids = set(variant_ids)

        ids_to_remove = existing_variant_ids - incoming_variant_ids
        if ids_to_remove:
            agent.assigned_items.filter(variant_id__in=ids_to_remove).delete()

        ids_to_add = incoming_variant_ids - existing_variant_ids
        assigned_count = 0
        for variant_id in ids_to_add:
            try:
                if biz:
                    variant = ItemVariant.objects.get(id=variant_id, item__type=biz)
                else:
                    variant = ItemVariant.objects.get(id=variant_id)
                AgentItem.objects.create(agent=agent, variant=variant)
                assigned_count += 1
            except ItemVariant.DoesNotExist:
                pass

        qs = (
            agent.assigned_items
            .select_related("variant__item")
            .prefetch_related("variant__sizes")
            .all()
        )
        item_groups = defaultdict(list)
        for ai in qs:
            item_groups[ai.variant.item_id].append(ai)

        result = []
        for item_id, agent_items in item_groups.items():
            item_obj = agent_items[0].variant.item
            result.append(
                AgentItemListSerializer.from_assigned_variants(
                    item_obj, agent_items, request
                )
            )

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

    def delete(self, request, agent_id, variant_id):
        agent = get_object_or_404(Agent, id=agent_id)
        agent_item = get_object_or_404(
            AgentItem, agent=agent, variant_id=variant_id
        )

        biz = admin_business(request.user)
        if biz and agent_item.variant.item.type != biz:
            return Response({"error": "Not found"}, status=404)

        agent_item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
