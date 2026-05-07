from django.db import models

from apps.agents.models import Agent


class Customer(models.Model):
    name = models.CharField(max_length=100)
    address = models.TextField()
    contact = models.CharField(max_length=20)
    agent = models.ForeignKey(Agent, on_delete=models.CASCADE, related_name="customers")

    def __str__(self):
        return self.name
