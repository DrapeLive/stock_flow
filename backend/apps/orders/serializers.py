from rest_framework import serializers
from .models import Order, OrderItem
from apps.items.models import Item
from apps.items.serializers import ItemVariantSerializer
from apps.customers.models import Customer
from apps.agents.models import Agent


class SimpleCustomerSerializer(serializers.ModelSerializer):

    class Meta:
        model = Customer
        fields = ["id", "name"]


class SimpleItemSerializer(serializers.ModelSerializer):

    class Meta:
        model = Item
        fields = ["id", "name", "price"]


class SimpleAgentSerializer(serializers.ModelSerializer):

    username = serializers.CharField(source="user.username")

    class Meta:
        model = Agent
        fields = ["id", "username"]


class OrderItemSerializer(serializers.ModelSerializer):

    item = SimpleItemSerializer(read_only=True)
    variant = ItemVariantSerializer(read_only=True)

    class Meta:
        model = OrderItem
        fields = "__all__"
        read_only_fields = ("order",)


class OrderSerializer(serializers.ModelSerializer):

    items = OrderItemSerializer(many=True, read_only=True)

    customer = serializers.PrimaryKeyRelatedField(
        queryset=Customer.objects.all(),
        write_only=True
    )

    agent_details = SimpleAgentSerializer(
        source="agent",
        read_only=True
    )

    customer_details = SimpleCustomerSerializer(
        source="customer",
        read_only=True
    )

    total_quantity = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = "__all__"

    def get_total_quantity(self, obj):
        return sum(i.quantity for i in obj.items.all())


class AddOrderItemSerializer(serializers.Serializer):

    qr_code = serializers.UUIDField()
    quantity = serializers.IntegerField()
    variant = serializers.IntegerField()
    size_group = serializers.CharField()

    def validate(self, attrs):

        try:
            attrs["item"] = Item.objects.get(
                qr_code=attrs["qr_code"]
            )
        except Item.DoesNotExist:
            raise serializers.ValidationError(
                "Invalid QR Code"
            )

        return attrs


class InvoiceSerializer(serializers.ModelSerializer):

    customer = SimpleCustomerSerializer()
    agent = SimpleAgentSerializer()

    items = OrderItemSerializer(many=True)

    total_price = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = [
            "id",
            "customer",
            "agent",
            "created_at",
            "status",
            "items",
            "total_price"
        ]

    def get_total_price(self, obj):

        total = 0

        for item in obj.items.all():
            total += item.item.price * item.quantity

        return total