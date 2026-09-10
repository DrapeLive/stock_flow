from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.agents.models import Agent
from apps.business.models import Brand
from apps.customers.models import Customer
from apps.items.models import Item, ItemVariant
from apps.orders.models import Order, OrderItem

User = get_user_model()


def get_auth_header(user):
    refresh = RefreshToken.for_user(user)
    return {"HTTP_AUTHORIZATION": f"Bearer {refresh.access_token}"}


class UnpackedOrderItemsTestBase(TestCase):
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

        self.customer = Customer.objects.create(
            name="ABC Fashions", contact="2222222222", agent=self.agent
        )

        self.item = Item.objects.create(
            name="Classic Shirt",
            price=500.00,
            type="gents",
            brand=self.brand,
        )

        self.variant = ItemVariant.objects.create(
            item=self.item, display_order="101"
        )

        self.order = Order.objects.create(
            customer=self.customer, agent=self.agent, status="PENDING"
        )

        self.url = "/api/orders/order-items/unpacked/"


class UnpackedOrderItemsSuccessTests(UnpackedOrderItemsTestBase):
    def test_returns_unpacked_items_from_pending_orders(self):
        OrderItem.objects.create(
            order=self.order,
            item=self.item,
            variant=self.variant,
            quantity=20,
            packed_quantity=0,
            item_name="Classic Shirt",
            item_price=500.00,
            size_group="M,L,XL",
            item_type="gents",
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

    def test_excludes_packed_items(self):
        OrderItem.objects.create(
            order=self.order,
            item=self.item,
            variant=self.variant,
            quantity=20,
            packed_quantity=20,
            item_name="Classic Shirt",
            item_price=500.00,
            size_group="M,L,XL",
            item_type="gents",
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 0)

    def test_excludes_items_from_non_pending_orders(self):
        dispatched_order = Order.objects.create(
            customer=self.customer, agent=self.agent, status="DISPATCHED"
        )
        OrderItem.objects.create(
            order=dispatched_order,
            item=self.item,
            variant=self.variant,
            quantity=20,
            packed_quantity=0,
            item_name="Classic Shirt",
            item_price=500.00,
            size_group="M,L,XL",
            item_type="gents",
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 0)

    def test_excludes_draft_order_items(self):
        draft_order = Order.objects.create(
            customer=self.customer, agent=self.agent, status="DRAFT"
        )
        OrderItem.objects.create(
            order=draft_order,
            item=self.item,
            variant=self.variant,
            quantity=20,
            packed_quantity=0,
            item_name="Classic Shirt",
            item_price=500.00,
            size_group="M,L,XL",
            item_type="gents",
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 0)

    def test_returns_lightweight_fields(self):
        OrderItem.objects.create(
            order=self.order,
            item=self.item,
            variant=self.variant,
            quantity=20,
            packed_quantity=0,
            item_name="Classic Shirt",
            item_price=500.00,
            size_group="M,L,XL",
            item_type="gents",
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self.url)

        item = response.data[0]
        self.assertIn("id", item)
        self.assertIn("item_name", item)
        self.assertIn("variant_display_order", item)
        self.assertIn("quantity", item)
        self.assertIn("size_group", item)
        self.assertIn("item_type", item)
        self.assertIn("piece_count", item)

        self.assertNotIn("item_price", item)
        self.assertNotIn("packed_quantity", item)
        self.assertNotIn("order", item)
        self.assertIn("variant_image", item)

    def test_correct_field_values(self):
        OrderItem.objects.create(
            order=self.order,
            item=self.item,
            variant=self.variant,
            quantity=25,
            packed_quantity=0,
            item_name="Classic Shirt",
            item_price=500.00,
            size_group="M,L,XL",
            item_type="gents",
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self.url)

        item = response.data[0]
        self.assertEqual(item["item_name"], "Classic Shirt")
        self.assertEqual(item["variant_display_order"], "101")
        self.assertEqual(item["quantity"], 25)
        self.assertEqual(item["size_group"], "M,L,XL")
        self.assertEqual(item["item_type"], "gents")
        self.assertEqual(item["piece_count"], 3)

    def test_empty_list_when_no_unpacked_items(self):
        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data, [])

    def test_multiple_unpacked_items(self):
        customer2 = Customer.objects.create(
            name="XYZ Garments", contact="3333333333", agent=self.agent
        )
        order2 = Order.objects.create(
            customer=customer2, agent=self.agent, status="PENDING"
        )

        OrderItem.objects.create(
            order=self.order,
            item=self.item,
            variant=self.variant,
            quantity=20,
            packed_quantity=0,
            item_name="Classic Shirt",
            item_price=500.00,
            size_group="M,L,XL",
            item_type="gents",
        )
        OrderItem.objects.create(
            order=order2,
            item=self.item,
            variant=self.variant,
            quantity=30,
            packed_quantity=0,
            item_name="Classic Shirt",
            item_price=500.00,
            size_group="S,M,L,XL",
            item_type="gents",
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)


class UnpackedOrderItemsIsolationTests(UnpackedOrderItemsTestBase):
    def test_unauthenticated_request_rejected(self):
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_agent_sees_only_own_items(self):
        OrderItem.objects.create(
            order=self.order,
            item=self.item,
            variant=self.variant,
            quantity=20,
            packed_quantity=0,
            item_name="Classic Shirt",
            item_price=500.00,
            size_group="M,L,XL",
            item_type="gents",
        )

        other_agent_user = User.objects.create_user(
            username="agent2",
            email="agent2@test.com",
            password="pass1234",
            role="AGENT",
        )
        other_agent = Agent.objects.create(
            user=other_agent_user, contact="4444444444"
        )
        other_customer = Customer.objects.create(
            name="Other Corp", contact="5555555555", agent=other_agent
        )
        other_order = Order.objects.create(
            customer=other_customer, agent=other_agent, status="PENDING"
        )
        OrderItem.objects.create(
            order=other_order,
            item=self.item,
            variant=self.variant,
            quantity=15,
            packed_quantity=0,
            item_name="Classic Shirt",
            item_price=500.00,
            size_group="M,L,XL",
            item_type="gents",
        )

        self.client.credentials(**get_auth_header(self.agent_user))
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["quantity"], 20)

    def test_admin_business_type_isolation(self):
        OrderItem.objects.create(
            order=self.order,
            item=self.item,
            variant=self.variant,
            quantity=20,
            packed_quantity=0,
            item_name="Classic Shirt",
            item_price=500.00,
            size_group="M,L,XL",
            item_type="gents",
        )

        kids_item = Item.objects.create(
            name="Kids Top", price=300.00, type="kids", brand=self.brand
        )
        kids_variant = ItemVariant.objects.create(
            item=kids_item, display_order="201"
        )
        kids_order = Order.objects.create(
            customer=self.customer, agent=self.agent, status="PENDING"
        )
        OrderItem.objects.create(
            order=kids_order,
            item=kids_item,
            variant=kids_variant,
            quantity=10,
            packed_quantity=0,
            item_name="Kids Top",
            item_price=300.00,
            size_group="20-36",
            item_type="kids",
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["item_name"], "Classic Shirt")

    def test_mixed_packed_and_unpacked_across_orders(self):
        customer2 = Customer.objects.create(
            name="XYZ Garments", contact="3333333333", agent=self.agent
        )
        order2 = Order.objects.create(
            customer=customer2, agent=self.agent, status="PENDING"
        )

        OrderItem.objects.create(
            order=self.order,
            item=self.item,
            variant=self.variant,
            quantity=20,
            packed_quantity=0,
            item_name="Classic Shirt",
            item_price=500.00,
            size_group="M,L,XL",
            item_type="gents",
        )
        OrderItem.objects.create(
            order=order2,
            item=self.item,
            variant=self.variant,
            quantity=30,
            packed_quantity=15,
            item_name="Classic Shirt",
            item_price=500.00,
            size_group="S,M,L,XL",
            item_type="gents",
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["quantity"], 20)
