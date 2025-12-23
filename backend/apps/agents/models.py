from django.db import models
from apps.accounts.models import User

# Create your models here.
class Agent(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    contact = models.CharField(max_length=20)

    def __str__(self):
        return self.user.username
