from rest_framework import serializers
from .models import Item, ItemVariant

KIDS_SIZES = ["20-24", "26-30", "32-36", "38"]
GENTS_SIZES = ["S", "M", "L", "XL", "XXL"]


class ItemVariantSerializer(serializers.ModelSerializer):

    class Meta:
        model = ItemVariant
        fields = "__all__"
        read_only_fields = ["item"]


# class ItemSizeSerializer(serializers.ModelSerializer):
#
#     class Meta:
#         model = ItemSize
#         fields = "__all__"
#         read_only_fields = ["item"]


class ItemSerializer(serializers.ModelSerializer):

    variants = ItemVariantSerializer(many=True)

    class Meta:
        model = Item
        fields = "__all__"

    def validate(self, data):

        sizes = self.initial_data.get("sizes", [])
        item_type = data.get("type")

        for size in sizes:

            if item_type == "kids" and size["size"] not in KIDS_SIZES:
                raise serializers.ValidationError(
                    f"{size['size']} is not valid for kids item"
                )

            if item_type == "gents" and size["size"] not in GENTS_SIZES:
                raise serializers.ValidationError(
                    f"{size['size']} is not valid for gents item"
                )

        return data

    def create(self, validated_data):

        variants_data = validated_data.pop("variants")
        sizes_data = validated_data.pop("sizes")

        item = Item.objects.create(**validated_data)

        for variant_data in variants_data:
            ItemVariant.objects.create(
                item=item,
                **variant_data
            )

        for size_data in sizes_data:
            ItemVariant.objects.create(
                item=item,
                **size_data
            )

        return item

    def update(self, instance, validated_data):

        variants_data = validated_data.pop("variants", [])
        sizes_data = validated_data.pop("sizes", [])

        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        instance.save()

        instance.variants.all().delete()

        for variant_data in variants_data:
            ItemVariant.objects.create(
                item=instance,
                **variant_data
            )

        instance.sizes.all().delete()

        for size_data in sizes_data:
            ItemVariant.objects.create(
                item=instance,
                **size_data
            )

        return instance