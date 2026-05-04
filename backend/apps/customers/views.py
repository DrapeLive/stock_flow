from rest_framework.viewsets import ModelViewSet
from .models import Customer
from .serializers import CustomerSerializer
from rest_framework.permissions import IsAuthenticated

class CustomerViewSet(ModelViewSet):
    serializer_class = CustomerSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user

        if user.role == 'ADMIN':
            return Customer.objects.all()
        return Customer.objects.filter(agent__user=user)

    def perform_create(self, serializer):
        if self.request.user.role == 'AGENT':
            serializer.save(agent=self.request.user.agent)
        else:
            serializer.save()
