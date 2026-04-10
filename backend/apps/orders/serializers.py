from rest_framework import serializers
from .models import Order, OrderItem
from apps.items.models import Item
from apps.items.models import ItemVariant
from apps.customers.models import Customer
from apps.agents.models import Agent
from apps.items.serializers import ItemSerializer


def get_piece_count(size_group, item_type='gents'):
    PIECE_COUNT = {
        'gents': {
            'M,L,XL': 3,
            'M,L,XL,XXL': 4,
            'S,M,L,XL': 4,
            'S,M,L,XL,XXL': 5,
        },
        'kids': {
            '20-24': 3,
            '26-30': 3,
            '32-36': 3,
            '38': 1,
            '20-36': 9,
            '20-38': 10,
            '26-36': 6,
            '26-38': 7,
            '20-30': 6,
        }
    }
    return PIECE_COUNT.get(item_type, {}).get(size_group, 1)


class SimpleCustomerSerializer(serializers.ModelSerializer):

    class Meta:
        model = Customer
        fields = ["id", "name","contact"]


# class SimpleItemSerializer(serializers.ModelSerializer):
#
#     class Meta:
#         model = Item
#         fields = ["id", "name", "price"]


class SimpleAgentSerializer(serializers.ModelSerializer):

    username = serializers.CharField(source="user.username")

    class Meta:
        model = Agent
        fields = ["id", "username","contact"]


class OrderItemSerializer(serializers.ModelSerializer):

    item_name_display = serializers.CharField(source="item_name", read_only=True)
    item_price_display = serializers.DecimalField(source="item_price", max_digits=10, decimal_places=2, read_only=True)
    variant_image_display = serializers.URLField(source="variant_image", read_only=True)
    size_display = serializers.CharField(source="size", read_only=True)
    piece_count = serializers.SerializerMethodField()

    class Meta:
        model = OrderItem
        fields = [
            "id",
            "item",
            "variant",
            "size_group",
            "item_type",
            "item_name",
            "item_name_display",
            "item_price",
            "item_price_display",
            "variant_image",
            "variant_image_display",
            "size",
            "size_display",
            "quantity",
            "packed_quantity",
            "piece_count",
        ]
        read_only_fields = ("order", "item_name", "item_price", "variant_image", "size")

    def get_piece_count(self, obj):
        return get_piece_count(obj.size_group, obj.item_type or 'gents')


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
    size_group = serializers.CharField()
    size = serializers.CharField(required=False, default="")

    def validate(self, attrs):

        try:
            variant = ItemVariant.objects.get(qr_code=attrs["qr_code"])
        except ItemVariant.DoesNotExist:
            raise serializers.ValidationError("Invalid QR Code")

        if variant.item.is_deleted:
            raise serializers.ValidationError("This item has been deleted")

        attrs["variant"] = variant
        attrs["item"] = variant.item

        request = self.context.get("request")
        if request and hasattr(variant.image, "url"):
            attrs["variant_image"] = request.build_absolute_uri(variant.image.url)
        else:
            attrs["variant_image"] = None

        attrs["item_name"] = variant.item.name
        attrs["item_price"] = variant.item.price

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
            if item.item is None:
                continue
            item_type = item.item_type if item.item_type else 'gents'
            piece_count = get_piece_count(item.size_group, item_type)
            total += float(item.item_price) * item.quantity * piece_count

        return total