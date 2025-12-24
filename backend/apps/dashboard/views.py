from rest_framework.views import APIView
from rest_framework.response import Response
from apps.orders.models import Order
from apps.agents.models import Agent

class AdminDashboardView(APIView):
    def get(self, request):
        data = {}
        for obj in Order.objects.all():
            data[obj.status.lower()] = Order.objects.filter(status=obj.status).count()

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