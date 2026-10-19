from datetime import timedelta

from django.conf import settings

from rest_framework import serializers

from apps.agents.models import Agent
from apps.business.models import Brand
from apps.customers.models import Customer
from apps.items.models import ItemVariant

from .models import Order, OrderItem
from .utils import get_piece_count


class SimpleCustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Customer
        fields = ["id", "name", "contact", "address", "gst"]


class SimpleAgentSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source="user.username")

    class Meta:
        model = Agent
        fields = ["id", "username", "contact"]


class SimpleBrandSerializer(serializers.ModelSerializer):
    logo_url = serializers.SerializerMethodField()

    class Meta:
        model = Brand
        fields = [
            "id",
            "name",
            "phone",
            "email",
            "address_line1",
            "address_line2",
            "gst",
            "logo_url",
        ]

    def get_logo_url(self, obj):
        request = self.context.get("request")
        if obj.logo and request:
            return request.build_absolute_uri(obj.logo.url)
        return None


class OrderItemSerializer(serializers.ModelSerializer):
    item_name_display = serializers.CharField(source="item_name", read_only=True)
    item_price_display = serializers.DecimalField(
        source="item_price", max_digits=10, decimal_places=2, read_only=True
    )
    variant_image_display = serializers.URLField(source="variant_image", read_only=True)
    variant_display_order = serializers.CharField(
        source="variant.display_order", read_only=True
    )
    variant_qr_code = serializers.CharField(
        source="variant.qr_code", read_only=True, allow_null=True
    )
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
            "variant_display_order",
            "variant_qr_code",
            "size",
            "size_display",
            "quantity",
            "packed_quantity",
            "piece_count",
        ]
        read_only_fields = ("order", "item_name", "item_price", "variant_image", "size")

    def get_piece_count(self, obj):
        return get_piece_count(obj.size_group, obj.item_type or "gents")

    def to_representation(self, instance):
        data = super().to_representation(instance)
        request = self.context.get("request")

        variant_image = data.get("variant_image")

        if not variant_image and request:
            if instance.variant and instance.variant.image:
                variant_image = request.build_absolute_uri(instance.variant.image.url)
                data["variant_image"] = variant_image
        elif variant_image and request and not variant_image.startswith("http"):
            data["variant_image"] = request.build_absolute_uri(variant_image)

        return data


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)

    customer = serializers.PrimaryKeyRelatedField(
        queryset=Customer.objects.filter(is_active=True), write_only=True
    )

    agent_details = SimpleAgentSerializer(source="agent", read_only=True)

    customer_details = SimpleCustomerSerializer(source="customer", read_only=True)

    created_by = serializers.PrimaryKeyRelatedField(read_only=True)

    total_sets = serializers.SerializerMethodField()
    total_pieces = serializers.SerializerMethodField()
    dispatch_history = serializers.SerializerMethodField()
    has_partial_dispatch_remainder = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = "__all__"
        read_only_fields = ("created_by", "split_from")

    def to_representation(self, instance):
        data = super().to_representation(instance)
        # A split order represents the remainder of the original customer
        # order. Expose the root order date even for older split rows whose
        # stored created_at was set to the split time.
        root = instance
        seen_ids = {root.pk}
        while root.split_from_id:
            root = root.split_from
            if root.pk in seen_ids:
                break
            seen_ids.add(root.pk)
        if root.pk != instance.pk:
            data["created_at"] = self.fields["created_at"].to_representation(
                root.created_at
            )
        return data

    def get_total_sets(self, obj):
        return sum(i.quantity for i in obj.items.all())

    def get_total_pieces(self, obj):
        total = 0
        for i in obj.items.all():
            piece_count = get_piece_count(i.size_group, i.item_type or "gents")
            total += i.quantity * piece_count
        return total

    def get_dispatch_history(self, obj):
        """Return dispatched ancestors for pending orders created by splits."""
        history = []
        seen_ids = {obj.pk}
        parent = obj
        while parent.split_from_id:
            parent = parent.split_from
            if parent.pk in seen_ids:
                break
            seen_ids.add(parent.pk)
            if parent.status == "DISPATCHED":
                history.append(
                    {
                        "id": parent.pk,
                        "dispatched_at": parent.dispatched_at,
                        "total_price": str(
                            sum(
                                (item.item_price or 0)
                                * item.quantity
                                * get_piece_count(
                                    item.size_group, item.item_type or "gents"
                                )
                                for item in parent.items.all()
                            )
                        ),
                    }
                )
        history.reverse()
        return history

    def get_has_partial_dispatch_remainder(self, obj):
        """Keep the indicator while any partial-dispatch remainder is active."""
        stack = [obj]
        seen_ids = set()
        active_statuses = {"PENDING", "PACKED", "EDITING"}
        while stack:
            current = stack.pop()
            if current.pk in seen_ids:
                continue
            seen_ids.add(current.pk)
            if (
                current.split_from_id
                and current.status in active_statuses
            ):
                return True
            stack.extend(current.split_orders.all())
        return False


class AdminDraftOrderSerializer(OrderSerializer):
    """OrderSerializer plus the derived draft expiry (no stored field).

    Used only by the admin abandoned-drafts list so existing order payloads
    stay byte-identical.
    """

    expires_at = serializers.SerializerMethodField()

    def get_expires_at(self, obj):
        return (obj.created_at + timedelta(minutes=30)).isoformat()


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
        image_url = getattr(variant.image, "url", None) if variant.image else None
        if request and image_url:
            attrs["variant_image"] = request.build_absolute_uri(image_url)
        else:
            attrs["variant_image"] = None

        attrs["item_name"] = variant.item.name
        attrs["item_price"] = variant.item.price

        return attrs


class UnpackedOrderItemSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    item_name = serializers.CharField()
    variant_display_order = serializers.CharField(
        source="variant.display_order", default=""
    )
    quantity = serializers.IntegerField()
    size_group = serializers.CharField()
    item_type = serializers.CharField()
    variant_image = serializers.SerializerMethodField()
    piece_count = serializers.SerializerMethodField()

    def get_variant_image(self, obj):
        request = self.context.get("request")
        image = obj.variant_image
        if not image and obj.variant and obj.variant.image:
            image = obj.variant.image.url
        if image and request and not image.startswith("http"):
            image = request.build_absolute_uri(image)
        return image

    def get_piece_count(self, obj):
        return get_piece_count(obj.size_group, obj.item_type or "gents")


class InvoiceSerializer(serializers.ModelSerializer):
    customer = SimpleCustomerSerializer()
    agent = SimpleAgentSerializer()
    items = OrderItemSerializer(many=True)
    brand = serializers.SerializerMethodField()
    total_price = serializers.SerializerMethodField()
    gst_rate = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = [
            "id",
            "customer",
            "agent",
            "brand",
            "created_at",
            "status",
            "items",
            "total_price",
            "gst_rate",
        ]

    def get_gst_rate(self, obj):
        return settings.GST_RATE

    def get_brand(self, obj):
        first_item = obj.items.first()
        if first_item and first_item.item and first_item.item.brand:
            serializer = SimpleBrandSerializer(
                first_item.item.brand, context=self.context
            )
            return serializer.data
        return None

    def get_total_price(self, obj):

        total = 0

        for item in obj.items.all():
            if item.item is None:
                continue
            item_type = item.item_type if item.item_type else "gents"
            piece_count = get_piece_count(item.size_group, item_type)
            total += float(item.item_price) * item.quantity * piece_count

        return total
