from rest_framework import serializers
from django.contrib.auth.hashers import make_password
from .models import Agent, AgentItem
from apps.accounts.models import User
from apps.items.models import Item

class ItemSimpleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Item
        fields = ('id', 'name', 'type', 'price')


class AgentItemSerializer(serializers.ModelSerializer):
    item = ItemSimpleSerializer(read_only=True)
    item_id = serializers.PrimaryKeyRelatedField(
        queryset=Item.objects.all(),
        source='item',
        write_only=True
    )

    class Meta:
        model = AgentItem
        fields = ('id', 'item', 'item_id', 'created_at')


class AgentUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields=('id', 'username','email', 'role')


class AgentSerializer(serializers.ModelSerializer):
    user = AgentUserSerializer(read_only=True)
    username = serializers.CharField(write_only=True)
    password = serializers.CharField(write_only=True)
    email = serializers.EmailField(write_only=True)

    total_customers = serializers.SerializerMethodField()
    assigned_items = serializers.SerializerMethodField()

    class Meta:
        model = Agent
        fields = ('id', 'username', 'user', 'email', 'password', 'contact', 'total_customers', 'assigned_items')

    def get_total_customers(self, obj):
        return obj.customers.count()

    def get_assigned_items(self, obj):
        return ItemSimpleSerializer(
            [ai.item for ai in obj.assigned_items.all()],
            many=True
        ).data

    def create(self, validated_data):
        user = User.objects.create(
            username=validated_data["username"],
            email=validated_data["email"],
            password=make_password(validated_data["password"]),
            role="AGENT"
        )

        agent = Agent.objects.create(
            user=user,
            contact=validated_data['contact']
        )

        return agent

    def update(self, instance, validated_data):
        user = instance.user

        if 'username' in validated_data:
            user.username = validated_data['username']

        if 'email' in validated_data:
            user.email = validated_data['email']

        if 'password' in validated_data:
            user.password = make_password(validated_data['password'])

        user.save()

        instance.contact = validated_data.get('contact', instance.contact)
        instance.save()

        return instance