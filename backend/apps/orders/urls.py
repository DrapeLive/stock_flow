from django.urls import path
from rest_framework.routers import DefaultRouter
from .views import OrderViewSet, AddOrderItemView, DeleteOrderItemView

router = DefaultRouter()
router.register('', OrderViewSet, basename='orders')

urlpatterns = router.urls + [
    path('<int:order_id>/add-item/', AddOrderItemView.as_view()),
    path('<int:order_id>/delete-item/<int:item_id>/', DeleteOrderItemView.as_view()),
]
