from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import AuthenticationFailed, ValidationError
from drf_spectacular.utils import extend_schema
from rest_framework_simplejwt.tokens import RefreshToken
from .serializers import (
    LoginRequestSerializer,
    LoginResponseSerializer,
    UserSerializer,
)


class LoginView(APIView):
    authentication_classes = []
    permission_classes = []

    @extend_schema(
        request=LoginRequestSerializer,
        responses={200: LoginResponseSerializer},
        tags=['Authentication'],
    )
    def post(self, request):
        serializer = LoginRequestSerializer(data=request.data)

        if not serializer.is_valid():
            # Return a flat { "error": "..." } so the frontend can read it
            first_error = next(iter(serializer.errors.values()))
            message = first_error[0] if isinstance(first_error, list) else str(first_error)
            return Response(
                {"error": message},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = serializer.validated_data['user']

        if user is None:
            return Response(
                {"error": "Invalid email or password"},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "role": user.role,
                "user_id": user.id,
                "business": user.business or None,
                "is_superuser": user.is_superuser,
            },
            status=status.HTTP_200_OK,
        )


class ProfileView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        responses={200: UserSerializer},
        tags=['Authentication'],
    )
    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data)
