"""Best-effort notification dispatch.

Push notifications are a side effect: a broker outage must never turn a
successful business operation into a 500, block the request, or stop later
``transaction.on_commit`` hooks from running. All Celery dispatch for
notifications should go through :func:`notify_user_safely`.
"""
import logging

from apps.notification.tasks import send_push_to_user

logger = logging.getLogger(__name__)


def notify_user_safely(user_id, title, body, urgency="high", ttl=86400, task=None):
    """Queue ``send_push_to_user`` without ever raising to the caller.

    ``retry=False`` disables kombu's publish retry so an unreachable broker
    fails fast instead of holding the request open.
    """
    sender = task or send_push_to_user
    try:
        sender.apply_async(
            args=(user_id, title, body),
            kwargs={"urgency": urgency, "ttl": ttl},
            retry=False,
        )
    except Exception:
        logger.exception(
            "Failed to queue push notification for user %s (best-effort)", user_id
        )
