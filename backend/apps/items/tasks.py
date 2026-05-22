import logging

from celery import shared_task
from django.core.management import call_command

logger = logging.getLogger(__name__)


@shared_task
def cleanup_orphaned_media_task():
    logger.info("Starting orphaned media cleanup")
    call_command("cleanup_orphaned_media", days_old=1)
    logger.info("Orphaned media cleanup finished")
