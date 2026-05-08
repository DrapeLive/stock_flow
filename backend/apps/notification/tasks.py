import json
import logging

from celery import shared_task
from django.conf import settings
from pywebpush import WebPushException, webpush

from .models import PushSubscription

logger = logging.getLogger(__name__)


@shared_task(bind=True)
def send_push_to_user(self, user_id, title, body):
    subscriptions = PushSubscription.objects.filter(user_id=user_id)

    if not subscriptions.exists():
        logger.warning(f"[PushTask] User {user_id} has no subscription — skipping")
        return

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
                data=json.dumps({"title": title, "body": body}),
                vapid_private_key=settings.PRIVATE_VAPID_KEY,
                vapid_claims={"sub": "mailto:muhammedmuflih9605@gmail.com"},
            )
            logger.info(f"[PushTask] Successfully sent to user {user_id}")

        except WebPushException as e:
            response = e.response
            is_gone = (
                (response is not None and response.status_code in (404, 410))
                or "410" in str(e)
                or "Gone" in str(e)
                or "No such subscription" in str(e)
            )
            if is_gone:
                logger.warning(
                    f"[PushTask] Subscription expired for user {user_id} — deleting"
                )
                sub.delete()
            else:
                logger.error(f"[PushTask] WebPush failed for user {user_id}: {e}")

        except Exception as e:
            logger.exception(f"[PushTask] Unexpected error for user {user_id}: {e}")
