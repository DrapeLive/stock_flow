from rest_framework import serializers
from .models import Item, ItemVariant, ItemSize

KIDS_SIZES = ["20-24", "26-30", "30-36", "38"]
GENTS_SIZES = ["S", "M", "L", "XL", "XXL"]

class ItemVariantSerializer(serializers.ModelSerializer):
    class Meta:
        model = ItemVariant
        fields = '__all__'
        read_only_fields = ['item']

class ItemSizeSerializer(serializers.ModelSerializer):
    class Meta:
        model = ItemSize
        fields = '__all__'
        read_only_fields = ['item']

class ItemSerializer(serializers.ModelSerializer):
    variants = ItemVariantSerializer(many=True)
    sizes = ItemSizeSerializer(many=True)
    class Meta:
        model = Item
        fields = '__all__'

    def create(self, validated_data):
        variants_data = validated_data.pop('variants')
        size_data = validated_data.pop('sizes')
        item = Item.objects.create(**validated_data)

        for variant_data in variants_data:
            ItemVariant.objects.create(item=item, **variant_data)
        for size in size_data:
            ItemSize.objects.create(item=item, **size )

        return item

    def update(self, instance, validated_data):
        variants_data = validated_data.pop('variants', [])
        sizes_data = validated_data.pop('sizes', [])

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        instance.variants.all().delete()
        for variant_data in variants_data:
            ItemVariant.objects.create(item=instance, **variant_data)

        instance.sizes.all().delete()
        for size_data in sizes_data:
            ItemSize.objects.create(item=instance, **size_data)

        return instance
