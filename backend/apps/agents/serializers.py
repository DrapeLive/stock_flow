from rest_framework import serializers
from django.contrib.auth.hashers import make_password
from collections import defaultdict
from .models import Agent, AgentItem
from apps.accounts.models import User
from apps.items.models import Item


class VariantSizeRangeSerializer(serializers.Serializer):
    size_range = serializers.CharField()
    stock = serializers.IntegerField()


class VariantColorSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    image = serializers.CharField(allow_null=True)
    size_ranges = VariantSizeRangeSerializer(many=True)
    qr_code = serializers.CharField(allow_null=True)


class AgentItemListSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    type = serializers.CharField()
    price = serializers.DecimalField(max_digits=10, decimal_places=2)
    variants = VariantColorSerializer(many=True)

    @staticmethod
    def get_variants(item, request=None):
        def get_image_url(image_obj):
            if request and image_obj:
                return request.build_absolute_uri(image_obj.url)
            elif image_obj:
                return image_obj.url
            return None

        variants_by_image = defaultdict(lambda: {"id": None, "image_obj": None, "qr_code": None, "sizes": defaultdict(int)})

        for variant in item.variants.all():
            image_key = variant.image.url if variant.image else None

            if variants_by_image[image_key]["id"] is None:
                variants_by_image[image_key]["id"] = variant.id
                variants_by_image[image_key]["image_obj"] = variant.image
                variants_by_image[image_key]["qr_code"] = variant.qr_code

            for size_obj in variant.sizes.all():
                variants_by_image[image_key]["sizes"][size_obj.size] += size_obj.stock

        result = []

        for _, data in variants_by_image.items():
            image = get_image_url(data["image_obj"])
            first_variant_id = data["id"]

            size_ranges = [
                {
                    "size_range": size,
                    "stock": stock
                }
                for size, stock in data["sizes"].items()
                if stock > 0
            ]

            result.append({
                "id": first_variant_id,
                "image": image,
                "qr_code": data["qr_code"],
                "size_ranges": size_ranges
            })

        return result
    @classmethod
    def from_item(cls, item, request=None):
        return cls({
            "id": item.id,
            "name": item.name,
            "type": item.type,
            "price": item.price,
            "variants": cls.get_variants(item, request)
        }).data


class AgentItemSerializer(serializers.ModelSerializer):
    item = AgentItemListSerializer(read_only=True)
    item_id = serializers.PrimaryKeyRelatedField(
        queryset=Item.objects.filter(is_deleted=False),
        source='item',
        write_only=True
    )

    class Meta:
        model = AgentItem
        fields = ('id', 'item', 'item_id', 'created_at')


class AgentUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields=('id', 'username','email', 'role', 'display_name')


class AgentSerializer(serializers.ModelSerializer):
    user = AgentUserSerializer(read_only=True)
    username = serializers.CharField(write_only=True)
    password = serializers.CharField(write_only=True)
    email = serializers.EmailField(write_only=True)
    display_name = serializers.CharField(write_only=True, required=False, allow_blank=True)

    total_customers = serializers.SerializerMethodField()
    assigned_items = serializers.SerializerMethodField()

    class Meta:
        model = Agent
        fields = ('id', 'username', 'user', 'email', 'password', 'contact', 'total_customers', 'assigned_items', 'display_name')

    def validate_username(self, value):
        instance = self.instance

        existing = User.objects.filter(username=value)

        if instance:
            existing = existing.exclude(id=instance.user.id)

        if existing.exists():
            raise serializers.ValidationError(
                f'Username "{value}" is already taken.'
            )

        return value

    def validate_email(self, value):
        instance = self.instance

        existing = User.objects.filter(email=value)

        if instance:
            existing = existing.exclude(id=instance.user.id)

        if existing.exists():
            raise serializers.ValidationError(
                f'Email "{value}" is already taken.'
            )

        return value

    def get_total_customers(self, obj):
        return obj.customers.count()

    def get_assigned_items(self, obj):
        request = self.context.get('request')
        return [
            AgentItemListSerializer.from_item(ai.item, request)
            for ai in obj.assigned_items.select_related('item').prefetch_related('item__variants__sizes').filter(item__is_deleted=False).all()
        ]

    def create(self, validated_data):
        display_name = validated_data.pop('display_name', '')
        user = User.objects.create(
            username=validated_data["username"],
            email=validated_data["email"],
            password=make_password(validated_data["password"]),
            role="AGENT",
            display_name=display_name
        )

        agent = Agent.objects.create(
            user=user,
            contact=validated_data['contact']
        )

        return agent

def update(self, instance, validated_data):
    user = instance.user

    if (
        'username' in validated_data
        and validated_data['username'] != user.username
    ):
        user.username = validated_data['username']

    if (
        'email' in validated_data
        and validated_data['email'] != user.email
    ):
        user.email = validated_data['email']

    if 'password' in validated_data:
        password = validated_data['password']

        if password and not user.check_password(password):
            user.password = make_password(password)

    if (
        'display_name' in validated_data
        and validated_data['display_name'] != user.display_name
    ):
        user.display_name = validated_data['display_name']

    user.save()

    if (
        'contact' in validated_data
        and validated_data['contact'] != instance.contact
    ):
        instance.contact = validated_data['contact']

    instance.save()

    return instance
