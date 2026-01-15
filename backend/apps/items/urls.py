from rest_framework.routers import DefaultRouter
from .views import ItemViewSet, ItemVariantViewSet

router = DefaultRouter()
router.register(r'', ItemViewSet)
router.register(r'variants', ItemVariantViewSet)

urlpatterns = router.urls
