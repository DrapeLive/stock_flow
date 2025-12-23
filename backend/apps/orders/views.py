from rest_framework.viewsets import ModelViewSet
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import Order, OrderItem, OrderStatus
from .serializers import OrderSerializer, AddOrderItemSerializer
from apps.accounts.permissions import IsAdmin, IsAgent
from rest_framework.permissions import IsAuthenticated
from drf_spectacular.utils import extend_schema

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
            status=OrderStatus.objects.get(name='Pending')
        )

class AddOrderItemView(APIView):
    permission_classes = [IsAgent]

    @extend_schema(
        request=AddOrderItemSerializer,
        responses={201: {"message": "Item added"}},
        tags=['Orders']
    )

    def post(self, request, order_id):
        serializer = AddOrderItemSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        order = Order.objects.get(id=order_id)
        item = serializer.validated_data['item']

        OrderItem.objects.create(
            order=order,
            item=item,
            quantity=serializer.validated_data['quantity'],
            selected_color=serializer.validated_data['selected_color'],
            selected_size=serializer.validated_data['selected_size'],
        )

        return Response({"message": "Item added"}, status=status.HTTP_201_CREATED)

class ChangeOrderStatusView(APIView):
    permission_classes = [IsAdmin]

    def patch(self, request, order_id):
        status_obj = OrderStatus.objects.get(id=request.data['status_id'])
        order = Order.objects.get(id=order_id)
        order.status = status_obj
        order.save()
        return Response({"message": "Status updated"})