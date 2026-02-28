
from django.contrib import admin
from django.urls import path, include
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
    SpectacularRedocView,
)

from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    # API schema
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),

    # Swagger UI
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),

    # Redoc (optional)
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),

    # reset password
    path('api/password/', include('django_rest_passwordreset.urls')),


    path('admin/', admin.site.urls),
    path('api/admins/', include('apps.admins.urls')),
    path('api/auth/', include('apps.accounts.urls')),
    path('api/agents/',include('apps.agents.urls')),
    path('api/customers/', include('apps.customers.urls')),
    path('api/items/', include('apps.items.urls')),
    path('api/orders/', include('apps.orders.urls')),
    path('api/dashboard/', include('apps.dashboard.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
