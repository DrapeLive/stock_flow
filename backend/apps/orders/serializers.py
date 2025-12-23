from rest_framework import serializers
from .models import OrderStatus, Order, OrderItem
from apps.items.models import Item

class OrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = '__all__'
        read_only_fields = ('order',)

class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)

    class Meta:
        model = Order
        fields = '__all__'


class AddOrderItemSerializer(serializers.Serializer):
    qr_code = serializers.UUIDField()
    quantity = serializers.IntegerField()
    selected_color = serializers.CharField()
    selected_size = serializers.CharField()

    def validate(self, attrs):
        try:
            attrs['item'] = Item.objects.get(qr_code=attrs['qr_code'])
        except Item.DoesNotExist:
            raise serializers.ValidationError("Invalid QR Code")
        return attrs

