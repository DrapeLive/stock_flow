from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AgentViewSet, AgentDetail, AgentItemsView, AgentItemDetailView

router = DefaultRouter()
router.register('', AgentViewSet, basename='agent')

urlpatterns = [
    path('', include(router.urls)),
    path('profile/<int:user_id>/', AgentDetail.as_view(), name='agent-by-user'),
    path('<int:agent_id>/items/', AgentItemsView.as_view(), name='agent-items'),
    path('<int:agent_id>/items/<int:item_id>/', AgentItemDetailView.as_view(), name='agent-item-detail'),
]

