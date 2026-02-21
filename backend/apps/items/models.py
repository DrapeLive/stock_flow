from django.db import models
import uuid

# Create your models here.
class Item(models.Model):
    TYPE_CHOICES = [
        ('kids', 'Kids'),
        ('gents', 'Gents')
    ]

    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    type = models.CharField(max_length=10, choices=TYPE_CHOICES, null=True)
    qr_code = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)

    def __str__(self):
        return self.name

def item_variant_image_path(instance, filename):
    return f"items/{instance.item.id}/{filename}"

class ItemVariant(models.Model):
    item = models.ForeignKey(Item, related_name="variants", on_delete=models.CASCADE)
    color = models.CharField(max_length=50)
    image = models.ImageField(upload_to=item_variant_image_path, null=True, blank=True)

class ItemSize(models.Model):
    item = models.ForeignKey(Item, related_name="sizes", on_delete=models.CASCADE)
    stock = models.PositiveIntegerField()
    size = models.CharField(max_length=10)