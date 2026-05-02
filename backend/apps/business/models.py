from django.db import models


class Brand(models.Model):
    name = models.CharField(max_length=200)
    phone = models.TextField()
    email = models.EmailField()
    address_line1 = models.TextField()
    address_line2 = models.TextField(blank=True, null=True)
    logo = models.ImageField(upload_to='brands/', blank=True, null=True)
    gst = models.CharField(max_length=20, blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name
