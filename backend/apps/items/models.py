from django.db import models
import uuid

# Create your models here.
class Item(models.Model):
    name = models.CharField(max_length=100)
    photo = models.ImageField(upload_to='items/',blank=True, null=True)
    description = models.TextField(blank=True)
    color = models.CharField(max_length=50)
    size = models.CharField(max_length=20)
    stock = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    qr_code = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)

    def __str__(self):
        return self.name