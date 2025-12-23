from rest_framework.routers import DefaultRouter
from .views import AgentViewSet

router = DefaultRouter()
router.register('',AgentViewSet)

urlpatterns = router.urls