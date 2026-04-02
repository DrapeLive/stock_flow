import os
from django.db.models.signals import post_delete
from django.dispatch import receiver
from .models import ItemVariant


@receiver(post_delete, sender=ItemVariant)
def delete_variant_image(sender, instance, **kwargs):
    if instance.image:
        if hasattr(instance.image, 'path') and instance.image.path:
            file_path = instance.image.path
            if os.path.isfile(file_path):
                os.remove(file_path)
