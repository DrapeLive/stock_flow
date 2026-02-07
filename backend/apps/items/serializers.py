from rest_framework import serializers
from .models import Item, ItemVariant

KIDS_SIZES = ["20-24", "26-30", "30-36", "38"]
GENTS_SIZES = ["S", "M", "L", "XL", "XXL"]

class ItemVariantSerializer(serializers.ModelSerializer):
    class Meta:
        model = ItemVariant
        fields = '__all__'
        read_only_fields = ['item']

    def validate(self, data):
        item_type = data.get("type")
        size = data.get("size")

        if item_type == "kids" and size not in KIDS_SIZES:
            raise serializers.ValidationError("Invalid kids size")

        if item_type == "gents" and size not in GENTS_SIZES:
            raise serializers.ValidationError("Invalid gents size")

        return data

class ItemSerializer(serializers.ModelSerializer):
    variants = ItemVariantSerializer(many=True)
    class Meta:
        model = Item
        fields = '__all__'

    def create(self, validated_data):
        variants_data = validated_data.pop('variants')
        item = Item.objects.create(**validated_data)

        for variant_data in variants_data:
            ItemVariant.objects.create(item=item, **variant_data)

        return item


