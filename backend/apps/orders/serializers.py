from rest_framework import serializers
from .models import Order, OrderItem
from apps.items.models import Item
from apps.items.serializers import ItemVariantSerializer

class SimpleItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = Item
        fields = ["id", "name", "price",]

class OrderItemSerializer(serializers.ModelSerializer):
    item = SimpleItemSerializer(read_only=True)
    variant = ItemVariantSerializer(read_only=True)

    class Meta:
        model = OrderItem
        fields = '__all__'
        read_only_fields = ('order',)

class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    total_quantity = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = '__all__'

    def get_total_quantity(self,obj):
        return sum(item.quantity for item in obj.items.all())


class AddOrderItemSerializer(serializers.Serializer):
    qr_code = serializers.UUIDField()
    quantity = serializers.IntegerField()
    variant = serializers.IntegerField()

    def validate(self, attrs):
        try:
            attrs['item'] = Item.objects.get(qr_code=attrs['qr_code'])
        except Item.DoesNotExist:
            raise serializers.ValidationError("Invalid QR Code")
        return attrs

