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
from apps.items.models import Item, ItemVariant, ItemVariantSize
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


class AgentItemAssignmentQRFlowTests(TestCase):
    """Scan QR -> by-qr resolves variant -> assign -> verified in DB.

    Mirrors the mobile Agent Item Assignment flow. The QR value is the uuid
    stored in ``ItemVariant.qr_code`` (what labels encode and scanners return).
    """

    def setUp(self):
        self.client = APIClient()

        self.brand = Brand.objects.create(
            name="QR Brand",
            phone="9998887776",
            email="qr@test.com",
            address_line1="7 QR St",
        )
        self.gents_admin = User.objects.create_user(
            username="qrgents",
            email="qrgents@test.com",
            password="pass1234",
            role="ADMIN",
            business="gents",
            brand=self.brand,
        )
        self.kids_admin = User.objects.create_user(
            username="qrkids",
            email="qrkids@test.com",
            password="pass1234",
            role="ADMIN",
            business="kids",
            brand=self.brand,
        )
        self.agent_user = User.objects.create_user(
            username="qragent", email="qragent@test.com", password="pass1234"
        )
        self.agent = Agent.objects.create(
            user=self.agent_user, contact="1111111111"
        )

        self.gents_item = Item.objects.create(
            name="Gents Shirt", price=500.00, type="gents", brand=self.brand
        )
        self.gents_variant = ItemVariant.objects.create(
            item=self.gents_item, display_order="1"
        )
        ItemVariantSize.objects.create(
            item_variant=self.gents_variant, size="M,L,XL", stock=5
        )

        self.kids_item = Item.objects.create(
            name="Kids Set", price=300.00, type="kids", brand=self.brand
        )
        self.kids_variant = ItemVariant.objects.create(
            item=self.kids_item, display_order="2"
        )
        ItemVariantSize.objects.create(
            item_variant=self.kids_variant, size="20-24", stock=4
        )

    def _scan(self, user, qr_value):
        return self.client.get(
            "/api/items/by-qr/", {"qr_code": qr_value}, **get_auth_header(user)
        )

    def _assign(self, user, agent_id, variant_ids):
        self.client.credentials(**get_auth_header(user))
        return self.client.post(
            f"/api/agents/{agent_id}/items/",
            {"variant_ids": variant_ids},
            format="json",
        )

    def test_scan_valid_qr_resolves_variant_and_admin_can_assign(self):
        resp = self._scan(
            self.gents_admin, str(self.gents_variant.qr_code)
        )
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data["matched_variant_id"], self.gents_variant.id)

        assign = self._assign(
            self.gents_admin, self.agent.id, [resp.data["matched_variant_id"]]
        )
        self.assertEqual(assign.status_code, status.HTTP_200_OK)
        self.assertTrue(
            AgentItem.objects.filter(
                agent=self.agent, variant=self.gents_variant
            ).exists()
        )

    def test_scan_again_already_assigned_keeps_single_row(self):
        self._assign(self.gents_admin, self.agent.id, [self.gents_variant.id])
        self._assign(self.gents_admin, self.agent.id, [self.gents_variant.id])

        self.assertEqual(
            AgentItem.objects.filter(
                agent=self.agent, variant=self.gents_variant
            ).count(),
            1,
        )

    def test_other_business_admin_cannot_assign_variant(self):
        # by-qr is business-scoped: the kids admin must not resolve the gents QR.
        hidden = self._scan(
            self.kids_admin, str(self.gents_variant.qr_code)
        )
        self.assertEqual(hidden.status_code, status.HTTP_404_NOT_FOUND)

        # The assignment endpoint must reject/ignore the out-of-scope variant.
        assign = self._assign(
            self.kids_admin, self.agent.id, [self.gents_variant.id]
        )
        self.assertEqual(assign.status_code, status.HTTP_200_OK)
        self.assertFalse(
            AgentItem.objects.filter(
                agent=self.agent, variant=self.gents_variant
            ).exists()
        )

    def test_cross_business_admin_assigns_own_variant_only(self):
        assign = self._assign(
            self.kids_admin,
            self.agent.id,
            [self.kids_variant.id, self.gents_variant.id],
        )
        self.assertEqual(assign.status_code, status.HTTP_200_OK)
        assigned = set(
            AgentItem.objects.filter(agent=self.agent).values_list(
                "variant_id", flat=True
            )
        )
        self.assertEqual(assigned, {self.kids_variant.id})

    def test_invalid_random_qr_returns_error(self):
        resp = self._scan(self.gents_admin, "not-a-real-qr-code")
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_missing_qr_param_returns_error_not_500(self):
        self.client.credentials(**get_auth_header(self.gents_admin))
        resp = self.client.get("/api/items/by-qr/")
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)


class AgentRestoreTests(TestCase):
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

        self.other_user = User.objects.create_user(
            username="agent2",
            email="agent2@test.com",
            password="pass1234",
            role="AGENT",
        )
        self.other_agent = Agent.objects.create(
            user=self.other_user, contact="2222222222"
        )

        self.customer = Customer.objects.create(
            name="ABC Fashions", contact="3333333333", agent=self.agent
        )
        self.item = Item.objects.create(
            name="Classic Shirt", price=500.00, type="gents"
        )
        self.variant = ItemVariant.objects.create(
            item=self.item, display_order="101"
        )
        self.agent_item = AgentItem.objects.create(
            agent=self.agent, variant=self.variant
        )
        self.order = Order.objects.create(
            customer=self.customer, agent=self.agent, status="PENDING"
        )

        self.agent.soft_delete()

    def _restore(self, agent_id, user=None, data=None):
        self.client.credentials(
            **get_auth_header(user or self.admin_user)
        )
        return self.client.post(
            f"/api/agents/{agent_id}/restore/",
            data or {},
            format="json",
        )

    def test_restore_reactivates_agent_and_user_and_clears_deactivated_at(self):
        response = self._restore(
            self.agent.id, data={"display_name": "Agent One", "contact": "999"}
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.agent.refresh_from_db()
        self.agent_user.refresh_from_db()
        self.assertTrue(self.agent.is_active)
        self.assertIsNone(self.agent.deactivated_at)
        self.assertTrue(self.agent_user.is_active)
        self.assertEqual(self.agent_user.display_name, "Agent One")
        self.assertEqual(self.agent.contact, "999")
        self.assertEqual(response.data["id"], self.agent.id)

    def test_restore_of_active_agent_returns_400(self):
        self._restore(self.agent.id)
        response = self._restore(self.agent.id)

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data, {"error": "Agent is already active"})

    def test_restore_missing_agent_returns_404(self):
        response = self._restore(999999)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_agent_caller_gets_403(self):
        response = self._restore(self.agent.id, user=self.other_user)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_business_scoped_admin_can_restore_agent(self):
        # Agent management is not business-scoped today (list/destroy/create
        # all allow any agent), so restore follows the same rule.
        response = self._restore(self.agent.id, user=self.admin_user)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.agent.refresh_from_db()
        self.assertTrue(self.agent.is_active)

    def test_restored_agent_can_log_in_and_data_is_unchanged(self):
        customer_ids = set(Customer.objects.values_list("id", flat=True))
        order_ids = set(Order.objects.values_list("id", flat=True))
        agent_item_ids = set(AgentItem.objects.values_list("id", flat=True))
        customer_agent_id = self.customer.agent_id
        order_agent_id = self.order.agent_id
        agent_item_agent_id = self.agent_item.agent_id

        before = self.client.post(
            "/api/auth/login/",
            {"email": self.agent_user.email, "password": "pass1234"},
            format="json",
        )
        self.assertEqual(before.status_code, status.HTTP_400_BAD_REQUEST)

        response = self._restore(self.agent.id)
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        after = self.client.post(
            "/api/auth/login/",
            {"email": self.agent_user.email, "password": "pass1234"},
            format="json",
        )
        self.assertEqual(after.status_code, status.HTTP_200_OK)
        self.assertEqual(after.data["role"], "AGENT")

        self.customer.refresh_from_db()
        self.order.refresh_from_db()
        self.agent_item.refresh_from_db()
        self.assertEqual(
            set(Customer.objects.values_list("id", flat=True)), customer_ids
        )
        self.assertEqual(
            set(Order.objects.values_list("id", flat=True)), order_ids
        )
        self.assertEqual(
            set(AgentItem.objects.values_list("id", flat=True)), agent_item_ids
        )
        self.assertEqual(self.customer.agent_id, customer_agent_id)
        self.assertEqual(self.order.agent_id, order_agent_id)
        self.assertEqual(self.agent_item.agent_id, agent_item_agent_id)


class AgentCreateConflictTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.admin_user = User.objects.create_user(
            username="admin1",
            email="admin1@test.com",
            password="pass1234",
            role="ADMIN",
        )
        self.client.credentials(**get_auth_header(self.admin_user))

        self.inactive_user = User.objects.create_user(
            username="deleted_agent",
            email="deleted@test.com",
            password="pass1234",
            role="AGENT",
        )
        self.inactive_agent = Agent.objects.create(
            user=self.inactive_user, contact="1111111111"
        )
        self.inactive_agent.soft_delete()

        self.active_user = User.objects.create_user(
            username="active_agent",
            email="active@test.com",
            password="pass1234",
            role="AGENT",
        )
        self.active_agent = Agent.objects.create(
            user=self.active_user, contact="2222222222"
        )

    def _create(self, **overrides):
        payload = {
            "username": "new_agent",
            "email": "new@test.com",
            "password": "pass1234",
            "contact": "3333333333",
        }
        payload.update(overrides)
        return self.client.post("/api/agents/", payload, format="json")

    def test_username_of_inactive_agent_returns_deactivated_conflict(self):
        response = self._create(username="deleted_agent")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["error"], "This agent was deleted.")
        self.assertEqual(response.data["code"], "agent_deactivated")
        self.assertEqual(response.data["agent_id"], self.inactive_agent.id)

    def test_email_of_inactive_agent_returns_deactivated_conflict(self):
        response = self._create(email="deleted@test.com")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["error"], "This agent was deleted.")
        self.assertEqual(response.data["code"], "agent_deactivated")
        self.assertEqual(response.data["agent_id"], self.inactive_agent.id)

    def test_email_of_active_agent_keeps_old_error(self):
        response = self._create(email="active@test.com")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertNotIn("code", response.data)
        self.assertIn("email", response.data)
        self.assertEqual(
            response.data["email"][0], 'Email "active@test.com" is already taken.'
        )

    def test_username_of_active_agent_keeps_old_error(self):
        response = self._create(username="active_agent")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertNotIn("code", response.data)
        self.assertIn("username", response.data)


class AgentInactiveListTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.admin_user = User.objects.create_user(
            username="admin1",
            email="admin1@test.com",
            password="pass1234",
            role="ADMIN",
        )
        self.active_user = User.objects.create_user(
            username="active_agent",
            email="active@test.com",
            password="pass1234",
            role="AGENT",
        )
        self.active_agent = Agent.objects.create(
            user=self.active_user, contact="1111111111"
        )
        self.inactive_user = User.objects.create_user(
            username="deleted_agent",
            email="deleted@test.com",
            password="pass1234",
            role="AGENT",
        )
        self.inactive_agent = Agent.objects.create(
            user=self.inactive_user, contact="2222222222"
        )
        self.inactive_agent.soft_delete()

    def test_default_list_is_unchanged(self):
        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get("/api/agents/")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            [row["id"] for row in response.data], [self.active_agent.id]
        )
        self.assertNotIn("deactivated_at", response.data[0])

    def test_inactive_param_returns_only_inactive_agents(self):
        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get("/api/agents/?inactive=true")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            [row["id"] for row in response.data], [self.inactive_agent.id]
        )
        self.assertIn("deactivated_at", response.data[0])

    def test_agent_caller_cannot_list_inactive_agents(self):
        self.client.credentials(**get_auth_header(self.active_user))
        response = self.client.get("/api/agents/?inactive=true")

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
