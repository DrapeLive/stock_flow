from django.db import models
from apps.accounts.models import User


class Agent(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    contact = models.CharField(max_length=20)

    def delete(self, *args, **kwargs):
        user = self.user
        super().delete(*args, **kwargs)
        user.delete()

    def __str__(self):
        return self.user.username


class AgentItem(models.Model):
    agent = models.ForeignKey(
        Agent,
        related_name="assigned_items",
        on_delete=models.CASCADE
    )
    item = models.ForeignKey(
        "items.Item",
        related_name="assigned_agents",
        on_delete=models.CASCADE
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("agent", "item")

    def __str__(self):
        return f"{self.agent.user.username} - {self.item.name}"
