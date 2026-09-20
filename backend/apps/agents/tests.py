from unittest import mock

from django.contrib.auth import get_user_model
from django.test import TestCase
from kombu.exceptions import OperationalError
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.agents.models import Agent, AgentItem
from apps.business.models import Brand
from apps.customers.models import Customer
from apps.items.models import Item, ItemVariant
from apps.orders.models import Order

User = get_user_model()


def get_auth_header(user):
    refresh = RefreshToken.for_user(user)
    return {"HTTP_AUTHORIZATION": f"Bearer {refresh.access_token}"}


class AgentDeleteInfoTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        self.admin_user = User.objects.create_user(
            username="admin1",
            email="admin1@test.com",
            password="pass1234",
            role="ADMIN",
            business="gents",
        )
        self.agent_user = User.objects.create_user(
            username="agent1",
            email="agent1@test.com",
            password="pass1234",
            role="AGENT",
        )
        self.agent = Agent.objects.create(
            user=self.agent_user, contact="1111111111"
        )
        self.customer = Customer.objects.create(
            name="ABC Fashions", contact="2222222222", agent=self.agent
        )

    def test_delete_info_orders_count_excludes_drafts(self):
        Order.objects.create(
            customer=self.customer, agent=self.agent, status="PENDING"
        )
        Order.objects.create(
            customer=self.customer, agent=self.agent, status="DRAFT"
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(f"/api/agents/{self.agent.id}/delete_info/")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["orders_count"], 1)


class AgentItemAssignNotifyResilienceTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        self.brand = Brand.objects.create(
            name="Test Brand",
            phone="1234567890",
            email="brand@test.com",
            address_line1="123 St",
        )
        self.admin_user = User.objects.create_user(
            username="admin1",
            email="admin1@test.com",
            password="pass1234",
            role="ADMIN",
            business="gents",
            brand=self.brand,
        )
        self.agent_user = User.objects.create_user(
            username="agent1",
            email="agent1@test.com",
            password="pass1234",
            role="AGENT",
        )
        self.agent = Agent.objects.create(
            user=self.agent_user, contact="1111111111"
        )
        self.item = Item.objects.create(
            name="Classic Shirt", price=500.00, type="gents", brand=self.brand
        )
        self.variant = ItemVariant.objects.create(
            item=self.item, display_order="101"
        )

    def test_assignment_succeeds_when_notify_raises(self):
        with mock.patch("apps.notification.utils.send_push_to_user") as task:
            task.apply_async.side_effect = OperationalError("Connection refused")

            self.client.credentials(**get_auth_header(self.admin_user))
            response = self.client.post(
                f"/api/agents/{self.agent.id}/items/",
                {"variant_ids": [self.variant.id]},
                format="json",
            )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(
            AgentItem.objects.filter(
                agent=self.agent, variant=self.variant
            ).exists()
        )
