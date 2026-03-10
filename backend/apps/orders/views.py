from django.db import transaction
from django.shortcuts import get_object_or_404

from rest_framework.viewsets import ModelViewSet
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .models import Order, OrderItem
from .serializers import (
    OrderSerializer,
    AddOrderItemSerializer,
    OrderItemSerializer,
    InvoiceSerializer
)

from apps.accounts.permissions import IsAgent
from rest_framework.permissions import IsAuthenticated

from apps.items.models import ItemVariant
from .utils import SIZE_MAPPING


class OrderViewSet(ModelViewSet):

    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):

        Order.objects.filter(items__isnull=True).delete()

        user = self.request.user

        qs = Order.objects.prefetch_related(
            "items__variant",
            "items__item"
        )

        if user.role == "ADMIN":
            return qs

        return qs.filter(agent__user=user)

    def perform_create(self, serializer):

        serializer.save(
            agent=self.request.user.agent
        )


class AddOrderItemView(APIView):

    permission_classes = [IsAgent]

    def post(self, request, order_id):

        serializer = AddOrderItemSerializer(
            data=request.data
        )

        serializer.is_valid(raise_exception=True)

        order = get_object_or_404(Order, id=order_id)

        item = serializer.validated_data["item"]
        qty = serializer.validated_data["quantity"]
        size_group = serializer.validated_data["size_group"]
        variant_id = serializer.validated_data["variant"]

        variant = get_object_or_404(
            ItemVariant,
            id=variant_id
        )

        item_type = item.type

        sizes = SIZE_MAPPING[item_type][size_group]

        with transaction.atomic():

            size_objects = ItemVariant.objects.select_for_update().filter(
                name__in=sizes
            )

            for s in size_objects:

                if s.stock < qty:
                    return Response(
                        {
                            "error": f"Insufficient stock in {s.name}"
                        },
                        status=400
                    )

            for s in size_objects:
                s.stock -= qty
                s.save()

            OrderItem.objects.create(
                order=order,
                item=item,
                variant=variant,
                size_group=size_group,
                quantity=qty
            )

        return Response(
            {"message": "Item added"},
            status=status.HTTP_201_CREATED
        )


class DeleteOrderItemView(APIView):

    permission_classes = [IsAgent]

    def delete(self, request, order_id, item_id):

        order = get_object_or_404(Order, id=order_id)

        order_item = get_object_or_404(
            OrderItem,
            id=item_id,
            order=order
        )

        item_type = order_item.item.type
        sizes = SIZE_MAPPING[item_type][order_item.size_group]

        with transaction.atomic():

            size_objects = ItemVariant.objects.select_for_update().filter(
                name__in=sizes
            )

            for s in size_objects:
                s.stock += order_item.quantity
                s.save()

            order_item.delete()

        return Response(
            {"message": "Item Deleted Successfully"}
        )


class InvoiceView(APIView):

    permission_classes = [IsAuthenticated]

    def get(self, request, order_id):

        order = get_object_or_404(
            Order.objects.prefetch_related(
                "items__item"
            ),
            id=order_id
        )

        serializer = InvoiceSerializer(order)

        return Response(serializer.data)


class OrderItemViewSet(ModelViewSet):

    queryset = OrderItem.objects.all()
    serializer_class = OrderItemSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):

        user = self.request.user

        if user.role == "ADMIN":
            return OrderItem.objects.all()

        return OrderItem.objects.filter(
            order__agent__user=user
        )