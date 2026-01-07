from rest_framework import serializers
from apps.accounts.models import User
from django.contrib.auth.hashers import make_password

class AdminSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'password')
        extra_kwargs = {
            'password': {'write_only': True}
        }

    def create(self, validated_data):
        validated_data['password'] = make_password(validated_data['password'])
        validated_data['role'] = 'ADMIN'
        return super().create(validated_data)
