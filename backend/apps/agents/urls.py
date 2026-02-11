from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AgentViewSet, AgentDetail

router = DefaultRouter()
router.register('', AgentViewSet, basename='agent')

urlpatterns = [
    path('', include(router.urls)),
    path('profile/<int:user_id>/', AgentDetail.as_view(), name='agent-by-user'),
]

