from django.db import transaction
from django.shortcuts import get_object_or_404
from django.db.models import F

from rest_framework.viewsets import ModelViewSet
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.decorators import action

from .models import Order, OrderItem, OrderLog
from .serializers import (
    OrderSerializer,
    AddOrderItemSerializer,
    OrderItemSerializer,
    InvoiceSerializer,
    get_piece_count
)

from apps.accounts.permissions import IsAgent
from rest_framework.permissions import IsAuthenticated

from apps.items.models import ItemVariant, ItemVariantSize
from apps.agents.models import AgentItem
from .utils import SIZE_MAPPING


class PlaceOrderView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, order_id):
        order = get_object_or_404(Order, id=order_id)

        if order.status != 'DRAFT':
            return Response(
                {"error": "Only DRAFT orders can be placed"},
                status=status.HTTP_400_BAD_REQUEST
            )

        if not order.items.exists():
            return Response(
                {"error": "Cannot place an empty order"},
                status=status.HTTP_400_BAD_REQUEST
            )

        out_of_stock_items = []

        with transaction.atomic():
            for order_item in order.items.select_related('item', 'variant'):
                if order_item.item is None or order_item.item.is_deleted:
                    continue

                item_type = order_item.item.type
                required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

                for size in required_sizes:
                    try:
                        size_obj = ItemVariantSize.objects.select_for_update().get(
                            item_variant=order_item.variant,
                            size=size
                        )
                    except ItemVariantSize.DoesNotExist:
                        out_of_stock_items.append({
                            "item_name": order_item.item_name,
                            "size_group": order_item.size_group,
                            "size": size,
                            "required": order_item.quantity,
                            "available": 0,
                            "order_item_id": order_item.id
                        })
                        continue

                    if size_obj.stock < order_item.quantity:
                        out_of_stock_items.append({
                            "item_name": order_item.item_name,
                            "size_group": order_item.size_group,
                            "size": size,
                            "required": order_item.quantity,
                            "available": size_obj.stock,
                            "order_item_id": order_item.id
                        })

            if out_of_stock_items:
                return Response(
                    {
                        "error": "Some items are no longer available. Another agent may have placed an order.",
                        "out_of_stock_items": out_of_stock_items
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            for order_item in order.items.select_related('item', 'variant'):
                if order_item.item is None or order_item.item.is_deleted:
                    continue

                item_type = order_item.item.type
                required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

                for size in required_sizes:
                    ItemVariantSize.objects.filter(
                        item_variant=order_item.variant,
                        size=size
                    ).update(stock=F('stock') - order_item.quantity)

            order.status = 'PENDING'
            order.save()

        return Response({
            "message": "Order placed successfully",
            "order_id": order.id
        })


def return_stock_for_item(order_item):
    """Return stock to warehouse for an order item."""
    if order_item.item is None or order_item.item.is_deleted:
        return
    
    item_type = order_item.item.type
    required_sizes = SIZE_MAPPING[item_type][order_item.size_group]
    
    for size in required_sizes:
        ItemVariantSize.objects.filter(
            item_variant=order_item.variant,
            size=size
        ).update(stock=F('stock') + order_item.quantity)


class OrderViewSet(ModelViewSet):

    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):

        if self.action == "list":
            Order.objects.filter(status='DRAFT').delete()

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

    def destroy(self, request, pk=None):
        order = self.get_object()
        
        if order.status != 'DRAFT':
            with transaction.atomic():
                for order_item in order.items.select_related('item', 'variant'):
                    return_stock_for_item(order_item)
                
                OrderLog.objects.create(
                    order=order,
                    action='ORDER_DELETED',
                    details={
                        'customer': order.customer.name,
                        'items_count': order.items.count(),
                        'status': order.status
                    },
                    performed_by=request.user
                )
        
        order.delete()
        
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=["post"], url_path="dispatch")
    def dispatch_order(self, request, pk=None):
        order = self.get_object()
        
        if order.status not in ['PENDING', 'PACKED']:
            return Response(
                {"error": "Only PENDING or PACKED orders can be dispatched"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        with transaction.atomic():
            for order_item in order.items.select_related('item', 'variant'):
                if order_item.item is None or order_item.item.is_deleted:
                    continue
                
                piece_count = get_piece_count(order_item.size_group, order_item.item_type or 'gents')
                total_pieces = order_item.quantity * piece_count
                packed_pieces = order_item.packed_quantity or 0
                unpacked_pieces = total_pieces - packed_pieces
                
                if unpacked_pieces > 0:
                    item_type = order_item.item.type
                    required_sizes = SIZE_MAPPING[item_type][order_item.size_group]
                    for size in required_sizes:
                        ItemVariantSize.objects.filter(
                            item_variant=order_item.variant,
                            size=size
                        ).update(stock=F('stock') + unpacked_pieces)
            
            OrderLog.objects.create(
                order=order,
                action='DISPATCHED',
                details={
                    'packed_items': sum(1 for i in order.items.all() if (i.packed_quantity or 0) > 0),
                    'total_items': order.items.count()
                },
                performed_by=request.user
            )
            
            order.status = 'DISPATCHED'
            order.save()
        
        return Response({"message": "Order dispatched successfully"})


class AddOrderItemView(APIView):

    permission_classes = [IsAgent]

    def post(self, request, order_id):

        serializer = AddOrderItemSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        order = get_object_or_404(Order, id=order_id)

        if order.status != 'DRAFT':
            return Response(
                {"error": "Items can only be added to DRAFT orders"},
                status=status.HTTP_400_BAD_REQUEST
            )

        agent = request.user.agent

        item = serializer.validated_data["item"]
        variant = serializer.validated_data["variant"]
        qty = serializer.validated_data["quantity"]
        size_group = serializer.validated_data["size_group"]

        if not AgentItem.objects.filter(agent=agent, item=item).exists():
            return Response(
                {"error": "This item is not assigned to you. Please contact admin for assignment."},
                status=status.HTTP_400_BAD_REQUEST
            )

        item_type = item.type

        if size_group not in SIZE_MAPPING[item_type]:
            return Response(
                {"error": "Invalid size group"},
                status=status.HTTP_400_BAD_REQUEST
            )

        required_sizes = SIZE_MAPPING[item_type][size_group]

        with transaction.atomic():

            for size in required_sizes:
                try:
                    size_obj = ItemVariantSize.objects.select_for_update().get(
                        item_variant__item=item,
                        item_variant=variant,
                        size=size
                    )
                except ItemVariantSize.DoesNotExist:
                    return Response(
                        {"error": f"Size {size} not found for this variant"},
                        status=status.HTTP_400_BAD_REQUEST
                    )

                if size_obj.stock < qty:
                    return Response(
                        {"error": f"Insufficient stock in {size}"},
                        status=status.HTTP_400_BAD_REQUEST
                    )

            for size in required_sizes:
                ItemVariantSize.objects.filter(
                    item_variant__item=item,
                    item_variant=variant,
                    size=size
                ).update(stock=F('stock') - qty)

            OrderItem.objects.create(
                order=order,
                item=item,
                variant=variant,
                size_group=size_group,
                item_type=item_type,
                item_name=serializer.validated_data["item_name"],
                item_price=serializer.validated_data["item_price"],
                variant_image=serializer.validated_data.get("variant_image"),
                size=serializer.validated_data.get("size", ""),
                quantity=qty
            )

        return Response(
            {"message": "Item added successfully"},
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

        if order.status != 'DRAFT':
            if order_item.item is not None and not order_item.item.is_deleted:
                item_type = order_item.item.type
                required_sizes = SIZE_MAPPING[item_type][order_item.size_group]

                with transaction.atomic():

                    for size in required_sizes:
                        ItemVariantSize.objects.filter(
                            item_variant=order_item.variant,
                            size=size
                        ).update(stock=F('stock') + order_item.quantity)
                
                OrderLog.objects.create(
                    order=order,
                    action='ITEM_DELETED',
                    details={
                        'item_name': order_item.item_name,
                        'size_group': order_item.size_group,
                        'quantity': order_item.quantity,
                        'stock_returned': True
                    },
                    performed_by=request.user
                )
        else:
            OrderLog.objects.create(
                order=order,
                action='ITEM_DELETED',
                details={
                    'item_name': order_item.item_name,
                    'size_group': order_item.size_group,
                    'quantity': order_item.quantity,
                    'stock_returned': False
                },
                performed_by=request.user
            )

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


class OrderLogsView(APIView):

    permission_classes = [IsAuthenticated]

    def get(self, request, order_id):
        order = get_object_or_404(Order, id=order_id)

        if request.user.role != 'ADMIN' and order.agent.user != request.user:
            return Response({"error": "Unauthorized"}, status=403)

        logs = order.logs.all().order_by('-created_at')

        from django.contrib.auth import get_user_model
        User = get_user_model()

        result = []
        for log in logs:
            user_name = None
            if log.performed_by:
                user_name = log.performed_by.username
            
            result.append({
                'id': log.id,
                'action': log.action,
                'details': log.details,
                'performed_by': user_name,
                'created_at': log.created_at.isoformat()
            })

        return Response(result)


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

    def update(self, request, *args, **kwargs):
        order_item = self.get_object()
        order = order_item.order

        if order.status not in ['DRAFT', 'PENDING', 'PACKED']:
            return Response(
                {"error": "Cannot edit items in this order status"},
                status=status.HTTP_400_BAD_REQUEST
            )

        old_quantity = order_item.quantity
        old_size_group = order_item.size_group

        new_quantity = request.data.get('quantity', old_quantity)
        new_size_group = request.data.get('size_group', old_size_group)

        if order.status != 'DRAFT':
            with transaction.atomic():
                if old_quantity != new_quantity or old_size_group != new_size_group:
                    return_stock_for_item(order_item)

                    if order_item.item:
                        item_type = order_item.item.type
                        required_sizes = SIZE_MAPPING[item_type][new_size_group]
                        
                        for size in required_sizes:
                            try:
                                size_obj = ItemVariantSize.objects.select_for_update().get(
                                    item_variant=order_item.variant,
                                    size=size
                                )
                            except ItemVariantSize.DoesNotExist:
                                return Response(
                                    {"error": f"Size {size} not found for this variant"},
                                    status=status.HTTP_400_BAD_REQUEST
                                )

                            if size_obj.stock < new_quantity:
                                return Response(
                                    {"error": f"Insufficient stock in {size}"},
                                    status=status.HTTP_400_BAD_REQUEST
                                )

                        for size in required_sizes:
                            ItemVariantSize.objects.filter(
                                item_variant=order_item.variant,
                                size=size
                            ).update(stock=F('stock') - new_quantity)

                    order_item.quantity = new_quantity
                    order_item.size_group = new_size_group

                    OrderLog.objects.create(
                        order=order,
                        action='ORDER_EDITED',
                        details={
                            'item_id': order_item.id,
                            'item_name': order_item.item_name,
                            'old_quantity': old_quantity,
                            'new_quantity': new_quantity,
                            'old_size_group': old_size_group,
                            'new_size_group': new_size_group
                        },
                        performed_by=request.user
                    )

                    order_item.save()

        return super().update(request, *args, **kwargs)
