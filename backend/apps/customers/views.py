import json

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from rest_framework.permissions import IsAuthenticated
from rest_framework.viewsets import ModelViewSet

from apps.agents.models import Agent

from .models import Customer
from .serializers import CustomerSerializer


class CustomerViewSet(ModelViewSet):
    serializer_class = CustomerSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user

        if user.role == "ADMIN":
            return Customer.objects.all()
        return Customer.objects.filter(agent__user=user)

    def perform_create(self, serializer):
        if self.request.user.role == "AGENT":
            serializer.save(agent=self.request.user.agent)
        else:
            serializer.save()


@csrf_exempt
@require_POST
def bulk_import_customers(request):
    try:
        customers = json.loads(request.body).get("customers", [])
        if not customers:
            return JsonResponse({"error": "No data provided."}, status=400)

        created, errors = [], []

        for i, row in enumerate(customers, 1):
            name = str(row.get("name", "")).strip()
            address = str(row.get("address", "")).strip()
            contact = str(row.get("contact", "")).strip()
            agent_username = str(row.get("agent", "")).strip()
            gst = str(row.get("gst", "")).strip()

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
                errors.append({"row": i, "error": f"Missing: {', '.join(missing)}"})
                continue

            try:
                agent = Agent.objects.select_related("user").get(
                    user__username=agent_username
                )
            except Agent.DoesNotExist:
                errors.append(
                    {"row": i, "error": f"Agent '{agent_username}' not found."}
                )
                continue

            created.append(
                Customer(
                    name=name,
                    address=address,
                    contact=contact,
                    agent=agent,
                    gst=gst,
                )
            )

        Customer.objects.bulk_create(created)

        return JsonResponse(
            {
                "created": len(created),
                "failed": len(errors),
                **({"errors": errors} if errors else {}),
            },
            status=207 if errors else 201,
        )

    except json.JSONDecodeError:
        return JsonResponse({"error": "Invalid JSON."}, status=400)
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)
