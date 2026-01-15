from django.db import models
import uuid

# Create your models here.
class Item(models.Model):

    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    qr_code = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)

    def __str__(self):
        return self.name

class ItemVariant(models.Model):
    TYPE_CHOICES = [
        ('kids', 'Kids'),
        ('gents', 'Gents')
    ]

    item = models.ForeignKey(Item, related_name="variants", on_delete=models.CASCADE)
    color = models.CharField(max_length=50)
    image = models.URLField(max_length=200)
    stock = models.PositiveIntegerField()
    type = models.CharField(max_length=10, choices=TYPE_CHOICES)
    size = models.CharField(max_length=10)