from django.db import models

from apps.agents.models import Agent
from transports.models import Transport


class Customer(models.Model):
    name = models.CharField(max_length=100, unique=True)
    address = models.TextField(unique=True)
    contact = models.CharField(max_length=20)
    gst = models.CharField(max_length=20, blank=True, default="")
    agent = models.ForeignKey(Agent, on_delete=models.SET_NULL, related_name="customers", null=True)
    preferred_transport = models.ForeignKey(Transport, on_delete=models.SET_NULL, null=True, blank=True, related_name="customers")

    def __str__(self):
        return self.name

    class Meta:
        unique_together = ("name", "address")
