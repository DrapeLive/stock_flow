from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import PushSubscription


class SaveSubscriptionView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        data = request.data
        endpoint = data.get("endpoint")
        keys = data.get("keys", {})
        p256dh = keys.get("p256dh")
        auth = keys.get("auth")

        if not all([endpoint, p256dh, auth]):
            return Response(
                {"error": "Missing required fields: endpoint, keys.p256dh, keys.auth"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        subscription, created = PushSubscription.objects.update_or_create(
            user=request.user,
            defaults={
                "endpoint": endpoint,
                "p256dh": p256dh,
                "auth": auth,
            },
        )

        return Response(
            {"message": "created" if created else "updated"},
            status=status.HTTP_200_OK,
        )
