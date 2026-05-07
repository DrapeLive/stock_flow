from django.urls import path

from .views import SaveSubscriptionView

urlpatterns = [
    path("save-subscription/", SaveSubscriptionView.as_view()),
]
