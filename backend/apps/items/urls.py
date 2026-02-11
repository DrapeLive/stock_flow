from rest_framework.routers import DefaultRouter
from .views import ItemViewSet, ItemVariantViewSet, ItemSizeViewSet

router = DefaultRouter()
router.register(r'', ItemViewSet)
router.register(r'variants', ItemVariantViewSet)
router.register(r'item-size', ItemSizeViewSet)
urlpatterns = router.urls
