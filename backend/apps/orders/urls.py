from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import (
    AddOrderItemView,
    AdminDraftAcceptView,
    AdminDraftRejectView,
    DeleteOrderItemView,
    InvoiceView,
    OrderItemViewSet,
    OrderLogsView,
    OrderViewSet,
    PlaceOrderView,
    SaveEditView,
    StartEditView,
)

router = DefaultRouter()
router.register("", OrderViewSet, basename="orders")
router.register("order-items", OrderItemViewSet, basename="order-items")

urlpatterns = router.urls + [
    path("<int:order_id>/place-order/", PlaceOrderView.as_view()),
    path("<int:order_id>/admin-accept-draft/", AdminDraftAcceptView.as_view()),
    path("<int:order_id>/admin-reject-draft/", AdminDraftRejectView.as_view()),
    path("<int:order_id>/add-item/", AddOrderItemView.as_view()),
    path("<int:order_id>/delete-item/<int:item_id>/", DeleteOrderItemView.as_view()),
    path("<int:order_id>/invoice/", InvoiceView.as_view()),
    path("<int:order_id>/logs/", OrderLogsView.as_view()),
    path("<int:order_id>/start-edit/", StartEditView.as_view()),
    path("<int:order_id>/save-edit/", SaveEditView.as_view()),
]
