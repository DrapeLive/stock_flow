from rest_framework.views import APIView
from rest_framework.response import Response
from apps.orders.models import Order, OrderStatus
from apps.agents.models import Agent

class AdminDashboardView(APIView):
    def get(self, request):
        data = {}
        for status in OrderStatus.objects.all():
            data[status.name.lower()] = Order.objects.filter(status=status).count()

        agents = []
        for agent in Agent.objects.all():
            agents.append({
                "agent": agent.user.username,
                "customers": agent.customers.count()
            })

        return Response({
            "order_summary": data,
            "agents": agents
        })