from rest_framework import serializers
from apps.accounts.models import User
from django.contrib.auth.hashers import make_password

class AdminSerializer(serializers.ModelSerializer):
    business = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'password', 'business')
        extra_kwargs = {
            'password': {'write_only': True}
        }
        read_only_fields = ('id',)

    def to_representation(self, instance):
        rep = super().to_representation(instance)
        if not self.context['request'].user.is_superuser:
            rep['business'] = instance.business
        return rep

    def create(self, validated_data):
        validated_data['password'] = make_password(validated_data['password'])
        validated_data['role'] = 'ADMIN'
        request_user = self.context['request'].user
        if request_user.is_superuser:
            validated_data['business'] = validated_data.get('business', '')
        elif request_user.business:
            validated_data['business'] = request_user.business
        return super().create(validated_data)
