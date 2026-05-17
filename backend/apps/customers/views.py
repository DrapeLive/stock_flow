import json

from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.filters import SearchFilter
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.viewsets import ModelViewSet

from apps.accounts.permissions import check_admin_pin
from apps.agents.models import Agent
from apps.orders.models import Order
from transports.models import Transport

from .models import Customer
from .serializers import CustomerSerializer


class CustomerPagination(PageNumberPagination):
    page_size = 50
    page_size_query_param = "page_size"
    max_page_size = 100


class CustomerViewSet(ModelViewSet):
    serializer_class = CustomerSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = CustomerPagination
    filter_backends = [SearchFilter]
    search_fields = ["name", "address", "contact"]

    def get_queryset(self):
        user = self.request.user
        if user.role == "ADMIN":
            return Customer.objects.filter(is_active=True)
        return Customer.objects.filter(agent__user=user, is_active=True)

    def perform_create(self, serializer):
        if self.request.user.role == "AGENT":
            serializer.save(agent=self.request.user.agent)
        else:
            serializer.save()

    @action(detail=True, methods=["get"])
    def delete_info(self, request, pk=None):
        customer = self.get_object()
        orders_count = Order.objects.filter(customer=customer).count()
        return Response({
            "orders_count": orders_count,
        })

    def destroy(self, request, *args, **kwargs):
        pin_error = check_admin_pin(request)
        if pin_error:
            return pin_error

        customer = self.get_object()
        customer.is_active = False
        customer.deactivated_at = timezone.now()
        customer.save(update_fields=["is_active", "deactivated_at"])
        return Response(status=status.HTTP_204_NO_CONTENT)


@csrf_exempt
@require_POST
def bulk_import_customers(request):
    try:
        customers = json.loads(request.body).get("customers", [])
        if not customers:
            return JsonResponse({"error": "No data provided."}, status=400)

        created_objs, errors = [], []
        existing_names = set(Customer.objects.values_list("name", flat=True))
        existing_addresses = set(Customer.objects.values_list("address", flat=True))

        for i, row in enumerate(customers, 1):
            name = str(row.get("name", "")).strip()
            address = str(row.get("address", "")).strip()
            contact = str(row.get("contact", "")).strip()
            agent_username = str(row.get("agent", "")).strip()
            gst = str(row.get("gst", "")).strip()
            transport_name = str(row.get("transport", "")).strip()

            missing = [
                f
                for f, v in [
                    ("name", name),
                    ("address", address),
                    ("contact", contact),
                    ("agent", agent_username),
                ]
                if not v
            ]
            if missing:
                errors.append(
                    {"row": i, "name": name, "error": f"Missing: {', '.join(missing)}"}
                )
                continue

            if name in existing_names:
                errors.append(
                    {
                        "row": i,
                        "name": name,
                        "error": f"Customer '{name}' already exists.",
                    }
                )
                continue

            if address in existing_addresses:
                errors.append(
                    {
                        "row": i,
                        "name": name,
                        "error": "Address already registered for another customer.",
                    }
                )
                continue

            try:
                agent = Agent.objects.select_related("user").get(
                    user__username=agent_username
                )
            except Agent.DoesNotExist:
                errors.append(
                    {
                        "row": i,
                        "name": name,
                        "error": f"Agent '{agent_username}' not found.",
                    }
                )
                continue

            transport = None
            if transport_name:
                try:
                    transport = Transport.objects.get(
                        name__iexact=transport_name, is_active=True
                    )
                except Transport.DoesNotExist:
                    errors.append(
                        {
                            "row": i,
                            "name": name,
                            "error": f"Transport '{transport_name}' not found or inactive.",
                        }
                    )
                    continue

            existing_names.add(name)
            existing_addresses.add(address)
            created_objs.append(
                Customer(
                    name=name,
                    address=address,
                    contact=contact,
                    agent=agent,
                    gst=gst,
                    preferred_transport=transport,
                )
            )

        Customer.objects.bulk_create(created_objs)
        return JsonResponse(
            {
                "created": len(created_objs),
                "failed": len(errors),
                **({"errors": errors} if errors else {}),
            },
            status=207 if errors else 201,
        )
    except json.JSONDecodeError:
        return JsonResponse({"error": "Invalid JSON."}, status=400)
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)
