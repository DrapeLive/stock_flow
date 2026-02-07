from django.db import transaction
from django.shortcuts import get_object_or_404
from rest_framework.viewsets import ModelViewSet
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import Order, OrderItem
from .serializers import OrderSerializer, AddOrderItemSerializer
from apps.accounts.permissions import IsAdmin, IsAgent
from rest_framework.permissions import IsAuthenticated
from drf_spectacular.utils import extend_schema

from ..items.models import ItemVariant


class OrderViewSet(ModelViewSet):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'ADMIN':
            return Order.objects.all()
        return Order.objects.filter(agent__user=user)

    def perform_create(self, serializer):
        serializer.save(
            agent=self.request.user.agent,
        )

class AddOrderItemView(APIView):
    permission_classes = [IsAgent]

    @extend_schema(
        request=AddOrderItemSerializer,
        responses={201: {"message": "Item added"}, 400: {"error": "Message"}},
        tags=['Orders']
    )

    def post(self, request, order_id):
        serializer = AddOrderItemSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        order = get_object_or_404(Order,id=order_id)
        item = serializer.validated_data["item"]
        variant_id = serializer.validated_data["variant"]
        qty = serializer.validated_data['quantity']

        with transaction.atomic():
            try:
                variant = ItemVariant.objects.select_for_update().get(
                    id=variant_id,
                )
            except ItemVariant.DoesNotExist:
                return Response(
                    {"error": "This specific color/size variant does not exist for this item."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            if variant.stock < qty:
                return Response(
                    {"error": f"Insufficient stock. Only {variant.stock} units available."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            OrderItem.objects.create(
                order=order,
                item=item,
                quantity=qty,
                variant=variant
            )

            variant.stock -= qty
            variant.save()

            return Response({"message": "Item added"}, status=status.HTTP_201_CREATED)
