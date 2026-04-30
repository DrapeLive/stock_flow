from rest_framework.views import APIView
from rest_framework.response import Response
from apps.orders.models import Order
from apps.agents.models import Agent
from apps.accounts.permissions import IsAdmin

class AdminDashboardView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        biz = request.user.business
        order_qs = Order.objects.filter(items__item_type=biz).distinct() if biz else Order.objects.all()
        data = {s.lower(): order_qs.filter(status=s).count() for s, _ in Order.STATUS_CHOICES}

        agents = []
        for agent in Agent.objects.all():
            customers_count = agent.customers.filter(order__items__item_type=biz).distinct().count() if biz else agent.customers.count()
            agents.append({
                "agent": agent.user.username,
                "customers": customers_count
            })

        return Response({
            "order_summary": data,
            "agents": agents
        })