from rest_framework.routers import DefaultRouter
from .views import ItemViewSet, ItemVariantViewSet
from django.conf import settings
from django.conf.urls.static import static

router = DefaultRouter()
router.register(r'', ItemViewSet)
router.register(r'variants', ItemVariantViewSet)
urlpatterns = router.urls+static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
