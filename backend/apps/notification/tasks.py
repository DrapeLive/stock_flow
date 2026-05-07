import json

from celery import shared_task
from django.conf import settings
from pywebpush import webpush

from .models import PushSubscription


@shared_task
def send_push_to_user(user_id, title, body):

    subscriptions = PushSubscription.objects.filter(user_id=user_id)

    for sub in subscriptions:
        try:
            webpush(
                subscription_info={
                    "endpoint": sub.endpoint,
                    "keys": {
                        "p256dh": sub.p256dh,
                        "auth": sub.auth,
                    },
                },
                data=json.dumps(
                    {
                        "title": title,
                        "body": body,
                    }
                ),
                vapid_private_key=settings.PRIVATE_VAPID_KEY,
                vapid_claims={"sub": "mailto:muhammedmuflih9605@gmail.com"},
            )

        except Exception as e:
            print(e)
