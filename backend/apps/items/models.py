from django.db import models
import uuid


class Item(models.Model):

    name = models.CharField(max_length=100)

    description = models.TextField(blank=True)

    price = models.DecimalField(
        max_digits=10,
        decimal_places=2
    )

    def __str__(self):
        return self.name


def item_variant_image_path(instance, filename):
    return f"items/{instance.item.id}/{filename}"


class ItemVariant(models.Model):
    SIZE_CHOICES = [
        ("20-24", "20-24"),
        ("26-30", "26-30"),
        ("32-36", "32-36"),
        ("38", "38"),
        ("S", "S"),
        ("M", "M"),
        ("L", "L"),
        ("XL", "XL"),
        ("XXL", "XXL")
    ]

    TYPE_CHOICES = [
        ('kids', 'Kids'),
        ('gents', 'Gents')
    ]

    item = models.ForeignKey(
        Item,
        related_name="variants",
        on_delete=models.CASCADE
    )

    qr_code = models.UUIDField(
        default=uuid.uuid4,
        unique=True,
        editable=False
    )

    type = models.CharField(
        max_length=10,
        choices=TYPE_CHOICES,
        default="NONE"
    )

    image = models.ImageField(
        upload_to=item_variant_image_path,
        null=True,
        blank=True
    )
    size = models.CharField(
        max_length=10,
        choices=SIZE_CHOICES
    )

    stock = models.PositiveIntegerField(default=0)

    def __str__(self):
        return f"{self.item.name}"

