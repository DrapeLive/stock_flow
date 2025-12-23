
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', include('apps.accounts.urls')),
    path('api/agents/',include('apps.agents.urls')),
    path('api/customers/', include('apps.customers.urls')),
    path('api/items/', include('apps.items.urls')),
    path('api/orders/', include('apps.orders.urls'))
]
