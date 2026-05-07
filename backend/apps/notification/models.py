from django.db import models

from apps.accounts.models import User


class PushSubscription(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)

    endpoint = models.TextField()

    p256dh = models.TextField()

    auth = models.TextField()

    created_at = models.DateTimeField(auto_now_add=True)
