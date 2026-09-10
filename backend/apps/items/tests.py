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

URL = "/api/items/customer-requirements/"


def get_auth_header(user):
    refresh = RefreshToken.for_user(user)
    return {"HTTP_AUTHORIZATION": f"Bearer {refresh.access_token}"}


def _make_order_item(**kwargs):
    defaults = {
        "quantity": 20,
        "packed_quantity": 0,
        "item_name": "Classic Shirt",
        "item_price": 500.00,
        "size_group": "M,L,XL",
        "item_type": "gents",
    }
    defaults.update(kwargs)
    return OrderItem.objects.create(**defaults)


class CustomerRequirementsAPITestBase(TestCase):
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

        self.customer1 = Customer.objects.create(
            name="ABC Fashions", contact="2222222222", agent=self.agent
        )

        self.customer2 = Customer.objects.create(
            name="XYZ Garments", contact="3333333333", agent=self.agent
        )

        self.item = Item.objects.create(
            name="Classic Shirt",
            price=500.00,
            type="gents",
            brand=self.brand,
        )

        self.variant1 = ItemVariant.objects.create(
            item=self.item, display_order="101"
        )
        self.variant2 = ItemVariant.objects.create(
            item=self.item, display_order="104"
        )

        self.order1 = Order.objects.create(
            customer=self.customer1, agent=self.agent, status="PENDING"
        )
        self.order2 = Order.objects.create(
            customer=self.customer2, agent=self.agent, status="PENDING"
        )
        self.order3 = Order.objects.create(
            customer=self.customer1, agent=self.agent, status="PENDING"
        )

    def _url(self, order_item_id):
        return f"{URL}?item_id={order_item_id}"


class CustomerRequirementsSuccessTests(CustomerRequirementsAPITestBase):
    def test_returns_pending_order_items(self):
        oi1 = _make_order_item(
            order=self.order1, item=self.item, variant=self.variant1, quantity=20
        )
        _make_order_item(
            order=self.order2, item=self.item, variant=self.variant2, quantity=30
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self._url(oi1.id))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["item"]["id"], self.item.id)
        self.assertEqual(response.data["item"]["name"], "Classic Shirt")
        self.assertEqual(len(response.data["customers"]), 2)

    def test_excludes_packed_order_items(self):
        oi1 = _make_order_item(
            order=self.order1, item=self.item, variant=self.variant1,
            quantity=20, packed_quantity=0,
        )
        _make_order_item(
            order=self.order2, item=self.item, variant=self.variant2,
            quantity=30, packed_quantity=10,
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self._url(oi1.id))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["customers"]), 1)
        self.assertEqual(response.data["customers"][0]["customer_name"], "ABC Fashions")

    def test_fully_packed_returns_empty_customers(self):
        oi1 = _make_order_item(
            order=self.order1, item=self.item, variant=self.variant1,
            quantity=20, packed_quantity=20,
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self._url(oi1.id))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["item"]["id"], self.item.id)
        self.assertEqual(response.data["customers"], [])

    def test_multiple_customers_same_item(self):
        oi1 = _make_order_item(
            order=self.order1, item=self.item, variant=self.variant1, quantity=20
        )
        _make_order_item(
            order=self.order2, item=self.item, variant=self.variant2, quantity=30
        )
        _make_order_item(
            order=self.order3, item=self.item, variant=self.variant1, quantity=25
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self._url(oi1.id))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["customers"]), 3)

        customer_names = [c["customer_name"] for c in response.data["customers"]]
        self.assertIn("ABC Fashions", customer_names)
        self.assertIn("XYZ Garments", customer_names)

    def test_correct_customer_name(self):
        oi1 = _make_order_item(
            order=self.order1, item=self.item, variant=self.variant1, quantity=20
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self._url(oi1.id))

        self.assertEqual(response.data["customers"][0]["customer_name"], "ABC Fashions")

    def test_correct_variant_display_order(self):
        oi1 = _make_order_item(
            order=self.order1, item=self.item, variant=self.variant1, quantity=20
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self._url(oi1.id))

        self.assertEqual(response.data["customers"][0]["variant_display_order"], "101")

    def test_correct_quantity(self):
        oi1 = _make_order_item(
            order=self.order1, item=self.item, variant=self.variant1, quantity=45
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self._url(oi1.id))

        self.assertEqual(response.data["customers"][0]["quantity"], 45)
        self.assertIn("variant_image", response.data["customers"][0])
        self.assertEqual(response.data["customers"][0]["size_group"], "M,L,XL")

    def test_only_packed_order_item_still_returns_others(self):
        oi1 = _make_order_item(
            order=self.order1, item=self.item, variant=self.variant1,
            quantity=20, packed_quantity=20,
        )
        _make_order_item(
            order=self.order2, item=self.item, variant=self.variant2,
            quantity=30, packed_quantity=0,
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self._url(oi1.id))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["customers"]), 1)
        self.assertEqual(response.data["customers"][0]["quantity"], 30)

    def test_invalid_order_item_id(self):
        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self._url(99999))

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(response.data["detail"], "OrderItem not found.")

    def test_missing_item_id_param(self):
        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(URL)

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(
            response.data["detail"], "item_id query parameter is required."
        )

    def test_deleted_item_returns_not_found(self):
        oi1 = _make_order_item(
            order=self.order1, item=self.item, variant=self.variant1, quantity=20
        )
        self.item.is_deleted = True
        self.item.save()

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self._url(oi1.id))

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(response.data["detail"], "Item not found.")


class CustomerRequirementsIsolationTests(CustomerRequirementsAPITestBase):
    def test_admin_sees_only_own_business_items(self):
        kids_item = Item.objects.create(
            name="Kids Shirt", price=300.00, type="kids", brand=self.brand
        )
        variant_kids = ItemVariant.objects.create(
            item=kids_item, display_order="201"
        )
        order_kids = Order.objects.create(
            customer=self.customer1, agent=self.agent, status="PENDING"
        )
        kids_oi = _make_order_item(
            order=order_kids, item=kids_item, variant=variant_kids,
            quantity=10, item_name="Kids Shirt", item_price=300.00,
            size_group="20-36", item_type="kids",
        )

        gents_oi = _make_order_item(
            order=self.order1, item=self.item, variant=self.variant1, quantity=20
        )

        self.client.credentials(**get_auth_header(self.admin_user))

        response = self.client.get(self._url(kids_oi.id))
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

        response = self.client.get(self._url(gents_oi.id))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["customers"]), 1)

    def test_other_admin_with_different_business_cannot_access(self):
        oi1 = _make_order_item(
            order=self.order1, item=self.item, variant=self.variant1, quantity=20
        )

        kids_admin = User.objects.create_user(
            username="admin3",
            email="admin3@test.com",
            password="pass1234",
            role="ADMIN",
            business="kids",
            brand=self.brand,
        )

        self.client.credentials(**get_auth_header(kids_admin))
        response = self.client.get(self._url(oi1.id))

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_agent_can_access(self):
        oi1 = _make_order_item(
            order=self.order1, item=self.item, variant=self.variant1, quantity=20
        )

        self.client.credentials(**get_auth_header(self.agent_user))
        response = self.client.get(self._url(oi1.id))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["customers"]), 1)

    def test_unauthenticated_request_rejected(self):
        oi1 = _make_order_item(
            order=self.order1, item=self.item, variant=self.variant1, quantity=20
        )

        response = self.client.get(self._url(oi1.id))

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_mixed_packed_and_unpacked_across_orders(self):
        oi1 = _make_order_item(
            order=self.order1, item=self.item, variant=self.variant1, quantity=20
        )
        _make_order_item(
            order=self.order2, item=self.item, variant=self.variant2,
            quantity=30, packed_quantity=15,
        )
        _make_order_item(
            order=self.order3, item=self.item, variant=self.variant1, quantity=25
        )

        self.client.credentials(**get_auth_header(self.admin_user))
        response = self.client.get(self._url(oi1.id))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["customers"]), 2)

        customer_names = [c["customer_name"] for c in response.data["customers"]]
        self.assertIn("ABC Fashions", customer_names)
        self.assertNotIn("XYZ Garments", customer_names)
