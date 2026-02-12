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

from ..items.models import ItemVariant, ItemSize


class OrderViewSet(ModelViewSet):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = Order.objects.prefetch_related(
            "items__variant",
            "items__item"
        )

        if user.role == 'ADMIN':
            return qs
        return qs.filter(agent__user=user)

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
        size_id = serializer.validated_data["size"]
        qty = serializer.validated_data['quantity']

        with transaction.atomic():
            try:
                size = ItemSize.objects.select_for_update().get(
                    id=size_id,
                )
                variant = ItemVariant.objects.select_for_update().get(
                    id=variant_id,
                )
            except ItemVariant.DoesNotExist:
                return Response(
                    {"error": "This specific color/size variant does not exist for this item."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            if size.stock < qty:
                return Response(
                    {"error": f"Insufficient stock. Only {size.stock} units available."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            OrderItem.objects.create(
                order=order,
                item=item,
                quantity=qty,
                variant=variant,
                size=size
            )

            size.stock -= qty
            size.save()

            return Response({"message": "Item added"}, status=status.HTTP_201_CREATED)
