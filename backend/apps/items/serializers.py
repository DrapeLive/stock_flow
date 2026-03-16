from rest_framework import serializers
from .models import Item, ItemVariant
from apps.orders.utils import SIZE_MAPPING

KIDS_SIZES = list(SIZE_MAPPING.get("kids", {}).keys())
GENTS_SIZES = list(SIZE_MAPPING.get("gents", {}).keys())

class ItemVariantSerializer(serializers.ModelSerializer):
    size = serializers.CharField()
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

    def _expand_variants(self, item_type, variants_data):
        """
        Expand each variant into multiple sub-variants using SIZE_MAPPING.
        Each sub-size inherits the stock and image from the parent variant.
        If no mapping exists for the size, the variant is kept as-is.
        """
        type_mapping = SIZE_MAPPING.get(item_type, {})
        expanded = []

        for variant_data in variants_data:
            size = variant_data.get("size")
            sub_sizes = type_mapping.get(size)

            if sub_sizes:
                for sub_size in sub_sizes:
                    expanded.append({**variant_data, "size": sub_size})
            else:
                expanded.append(variant_data)

        return expanded

    def create(self, validated_data):
        variants_data = validated_data.pop("variants", [])
        item = Item.objects.create(**validated_data)

        expanded_variants = self._expand_variants(item.type, variants_data)
        for variant_data in expanded_variants:
            ItemVariant.objects.create(item=item, **variant_data)

        return item

    def update(self, instance, validated_data):
        variants_data = validated_data.pop("variants", [])

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        expanded_variants = self._expand_variants(instance.type, variants_data)
        incoming_sizes = {v["size"] for v in expanded_variants}
        existing = {v.size: v for v in instance.variants.all()}

        # Delete removed sizes
        for size, variant in existing.items():
            if size not in incoming_sizes:
                variant.delete()

        # Create or update
        for variant_data in expanded_variants:
            size = variant_data["size"]
            if size in existing:
                existing[size].stock = variant_data.get("stock", existing[size].stock)
                existing[size].save()
            else:
                ItemVariant.objects.create(item=instance, **variant_data)

        return instance
