from rest_framework import serializers
from .models import Customer
from apps.orders.models import Order

class CustomerSerializer(serializers.ModelSerializer):
    total_orders = serializers.SerializerMethodField()
    agent_name = serializers.CharField(source="agent.user.get_name", read_only=True)

    class Meta:
        model = Customer
        fields = '__all__'

    def get_total_orders(self, obj):
        return Order.objects.filter(customer=obj).count()