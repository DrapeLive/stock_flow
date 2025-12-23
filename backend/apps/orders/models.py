from django.db import models
from apps.customers.models import Customer
from apps.agents.models import Agent
from apps.items.models import Item

# Create your models here.

class OrderStatus(models.Model):
    name = models.CharField(max_length=50)

    def __str__(self):
        return self.name

class Order(models.Model):
    customer = models.ForeignKey(Customer, on_delete=models.CASCADE)
    agent = models.ForeignKey(Agent, on_delete=models.CASCADE)
    status = models.ForeignKey(OrderStatus, on_delete=models.PROTECT)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Order #{self.id}"

class OrderItem(models.Model):
    order = models.ForeignKey(Order, related_name='items', on_delete=models.CASCADE)
    item = models.ForeignKey(Item, on_delete=models.PROTECT)
    quantity = models.PositiveIntegerField()
    packed_quantity = models.PositiveIntegerField(default=0)
    selected_color = models.CharField(max_length=50)
    selected_size = models.CharField(max_length=20)

    def __str__(self):
        return f"{self.item.name} x {self.quantity}"


