from django.db import models
from django.contrib.auth import get_user_model
from apps.customers.models import Customer
from apps.agents.models import Agent
from apps.items.models import Item, ItemVariant


class Order(models.Model):

    STATUS_CHOICES = (
        ('DRAFT', 'Draft'),
        ('PENDING', 'Pending'),
        ('PACKED', 'Packed'),
        ('DISPATCHED', 'Dispatched')
    )

    customer = models.ForeignKey(Customer, on_delete=models.CASCADE)
    agent = models.ForeignKey(Agent, on_delete=models.CASCADE)

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='DRAFT'
    )

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Order #{self.id}"


class OrderLog(models.Model):

    ACTION_CHOICES = (
        ('ITEM_DELETED', 'Item Deleted'),
        ('ORDER_DELETED', 'Order Deleted'),
        ('ORDER_EDITED', 'Order Edited'),
        ('DISPATCHED', 'Dispatched'),
    )

    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='logs'
    )
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    details = models.JSONField(default=dict, blank=True)
    performed_by = models.ForeignKey(
        get_user_model(),
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Order #{self.order_id} - {self.action}"


class OrderItem(models.Model):

    order = models.ForeignKey(
        Order,
        related_name='items',
        on_delete=models.CASCADE
    )

    item = models.ForeignKey(
        Item,
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )

    variant = models.ForeignKey(
        ItemVariant,
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )

    size_group = models.CharField(max_length=50, default="NONE")
    item_type = models.CharField(max_length=10, default="gents")

    item_name = models.CharField(max_length=100, default="Unknown Item")
    item_price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    variant_image = models.URLField(null=True, blank=True)
    size = models.CharField(max_length=10, default="")

    quantity = models.PositiveIntegerField()

    packed_quantity = models.PositiveIntegerField(default=0)

    def __str__(self):
        return f"{self.item_name} x {self.quantity}"