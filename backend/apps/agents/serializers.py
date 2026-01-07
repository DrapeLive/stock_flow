from rest_framework import serializers
from django.contrib.auth.hashers import make_password
from .models import Agent
from apps.accounts.models import User

class AgentUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields=('id', 'username','email', 'role')

class AgentSerializer(serializers.ModelSerializer):
    user = AgentUserSerializer(read_only=True)
    username = serializers.CharField(write_only=True)
    password = serializers.CharField(write_only=True)
    email = serializers.EmailField(write_only=True)

    class Meta:
        model = Agent
        fields = ('id', 'username', 'user', 'email', 'password', 'contact')

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