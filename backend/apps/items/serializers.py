from rest_framework import serializers
from .models import Item, ItemVariant

KIDS_SIZES = ["20-24", "26-30", "32-36", "38"]
GENTS_SIZES = ["S", "M,L,XL", "XXL"]


class ItemVariantSerializer(serializers.ModelSerializer):
    class Meta:
        model = ItemVariant
        fields = "__all__"
        read_only_fields = ["item"]


class ItemSerializer(serializers.ModelSerializer):
    variants = ItemVariantSerializer(many=True)

    class Meta:
        model = Item
        fields = "__all__"

    def validate(self, data):
        variants = data.get("variants", [])
        item_type = data.get("type")

        for variant in variants:
            size = variant.get("size")
            if item_type == "kids" and size not in KIDS_SIZES:
                raise serializers.ValidationError(
                    f"'{size}' is not a valid size for a kids item."
                )
            if item_type == "gents" and size not in GENTS_SIZES:
                raise serializers.ValidationError(
                    f"'{size}' is not a valid size for a gents item."
                )

        return data

    def create(self, validated_data):
        variants_data = validated_data.pop("variants", [])
        item = Item.objects.create(**validated_data)

        for variant_data in variants_data:
            ItemVariant.objects.create(item=item, **variant_data)

        return item

    def update(self, instance, validated_data):
        variants_data = validated_data.pop("variants", [])

        # Update scalar fields on the item
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        # Upsert variants by size — preserves existing IDs and qr_codes.
        # Sizes present in the payload are created-or-updated.
        # Sizes no longer in the payload are deleted.
        incoming_sizes = {v["size"] for v in variants_data}
        existing       = {v.size: v for v in instance.variants.all()}

        # Delete removed sizes
        for size, variant in existing.items():
            if size not in incoming_sizes:
                variant.delete()

        # Create or update
        for variant_data in variants_data:
            size = variant_data["size"]
            if size in existing:
                # Update stock only — image is handled separately via PATCH
                existing[size].stock = variant_data.get("stock", existing[size].stock)
                existing[size].save()
            else:
                ItemVariant.objects.create(item=instance, **variant_data)

        return instance
