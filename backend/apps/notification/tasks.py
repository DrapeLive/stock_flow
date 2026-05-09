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
        logger.warning(f"[PushTask] No subscriptions for user {user_id}")
        return

    success_count = 0

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

            success_count += 1

        except WebPushException as e:
            response = e.response

            if response is not None:
                logger.error(
                    f"[PushTask] Push rejected "
                    f"(user={user_id}, sub={sub.id}) "
                    f"status={response.status_code} "
                    f"body={response.text!r}"
                )

                if response.status_code in (404, 410):
                    logger.warning(
                        f"[PushTask] Expired subscription "
                        f"(user={user_id}, sub={sub.id}) — deleting"
                    )
                    sub.delete()

            else:
                logger.error(
                    f"[PushTask] WebPush failed (user={user_id}, sub={sub.id}): {e}"
                )

        except Exception as e:
            logger.exception(
                f"[PushTask] Unexpected error (user={user_id}, sub={sub.id}): {e}"
            )

    logger.info(
        f"[PushTask] Sent push to {success_count}/{subscriptions.count()} "
        f"subscriptions for user {user_id}"
    )
