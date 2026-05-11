import json
import logging

from celery import shared_task
from django.conf import settings
from pywebpush import WebPushException, webpush

from .models import PushSubscription

logger = logging.getLogger(__name__)


@shared_task(bind=True)
def send_push_to_user(self, user_id, title, body, urgency="high", ttl=86400):
    try:
        sub = PushSubscription.objects.get(user_id=user_id)
    except PushSubscription.DoesNotExist:
        logger.warning(f"[PushTask] No subscription for user {user_id} — skipping")
        return
    try:
        webpush(
            subscription_info={
                "endpoint": sub.endpoint,
                "keys": {
                    "p256dh": sub.p256dh,
                    "auth": sub.auth,
                },
            },
            data=json.dumps({"title": title, "body": body}),
            vapid_private_key=settings.PRIVATE_VAPID_KEY,
            vapid_claims={"sub": "mailto:muhammedmuflih9605@gmail.com"},
            ttl=ttl,
            headers={"Urgency": urgency},
        )
        logger.info(f"[PushTask] Sent push to user {user_id} (urgency={urgency})")
    except WebPushException as e:
        response = e.response
        if response is not None:
            logger.error(
                f"[PushTask] Push service rejected for user {user_id} — "
                f"status={response.status_code}, body={response.text!r}"
            )
            if response.status_code in (404, 410):
                logger.warning(
                    f"[PushTask] Subscription expired for user {user_id} — deleting"
                )
                sub.delete()
        else:
            logger.error(
                f"[PushTask] WebPush failed (no response) for user {user_id}: {e}"
            )
    except Exception as e:
        logger.exception(f"[PushTask] Unexpected error for user {user_id}: {e}")
