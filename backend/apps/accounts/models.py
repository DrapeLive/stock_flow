from django.db import models
from django.contrib.auth.models import AbstractUser

# Create your models here.

class User(AbstractUser):
    ROLE_CHOICES = (
        ('ADMIN', 'Admin'),
        ('AGENT', 'Agent')
    )
    BUSINESS_CHOICES = (
        ('gents', 'Gents'),
        ('kids', 'Kids'),
    )

    email = models.EmailField(unique=True)
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, blank=True)
    business = models.CharField(max_length=10, choices=BUSINESS_CHOICES, blank=True)

    def save(self, *args, **kwargs):
        if self.is_superuser:
            self.role = 'ADMIN'
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.username} ({self.role})"