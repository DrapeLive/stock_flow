"""Manual PostgreSQL concurrency probe for the Phase 1 order-row lock.

Run only against an isolated Django test database, for example from a
temporary container on the project's Compose network. This module is outside
apps.orders and is not included in the regular apps.orders suite.
"""

import inspect
import threading
import time
import textwrap
from datetime import datetime, timezone
from unittest import mock

from django.db import connection, connections
from django.test import TransactionTestCase
from rest_framework.test import APIRequestFactory, force_authenticate

from apps.accounts.models import User
from apps.agents.models import Agent
from apps.business.models import Brand
from apps.customers.models import Customer
from apps.items.models import Item, ItemVariant, ItemVariantSize
from apps.orders.models import Order, OrderItem
from apps.orders.views import AdminDraftAcceptView, PlaceOrderView
import apps.orders.views as order_views


class OrderRowLockPostgresTests(TransactionTestCase):
    """Requires PostgreSQL; SQLite does not implement SELECT FOR UPDATE."""

    reset_sequences = True

    def setUp(self):
        self.brand = Brand.objects.create(
            name="Phase 1b probe",
            phone="1",
            email="phase1b@example.com",
            address_line1="Test",
        )
        self.agent_user = User.objects.create_user(
            username="phase1b-agent",
            email="phase1b-agent@example.com",
            password="unused",
            role="AGENT",
        )
        self.agent = Agent.objects.create(user=self.agent_user, contact="111")
        self.admin = User.objects.create_user(
            username="phase1b-admin",
            email="phase1b-admin@example.com",
            password="unused",
            role="ADMIN",
            business="gents",
            brand=self.brand,
        )
        self.customer = Customer.objects.create(
            name="Phase 1b test customer", contact="222", agent=self.agent
        )
        self.item = Item.objects.create(
            name="Phase 1b test item", price=1, type="gents", brand=self.brand
        )
        self.variant = ItemVariant.objects.create(item=self.item)
        self.size = ItemVariantSize.objects.create(
            item_variant=self.variant, size="M,L,XL", stock=10
        )
        self.order = Order.objects.create(
            customer=self.customer,
            agent=self.agent,
            created_by=self.agent_user,
            status="DRAFT",
        )
        OrderItem.objects.create(
            order=self.order,
            item=self.item,
            variant=self.variant,
            size_group="M,L,XL",
            item_type="gents",
            item_name=self.item.name,
            item_price=1,
            quantity=5,
        )
        self.factory = APIRequestFactory()
        notification_patch = mock.patch("apps.orders.views.notify_user_safely")
        notification_patch.start()
        self.addCleanup(notification_patch.stop)

    def _place_view(self):
        request = self.factory.post("/place-order/", {}, format="json")
        force_authenticate(request, user=self.agent_user)
        return PlaceOrderView.as_view()(request, order_id=self.order.pk)

    def _accept_view(self):
        request = self.factory.post("/admin-accept-draft/", {}, format="json")
        force_authenticate(request, user=self.admin)
        return AdminDraftAcceptView.as_view()(request, order_id=self.order.pk)

    def _run_lock_race(self, calls):
        """Hold the first Order lock until PostgreSQL reports the second wait."""
        start_together = threading.Barrier(2)
        first_lock_acquired = threading.Event()
        second_lock_attempted = threading.Event()
        second_lock_query_finished = threading.Event()
        release_first = threading.Event()
        holder_guard = threading.Lock()
        holder = [None]
        second_pid = [None]
        query_timings = {}
        responses = {}
        errors = []

        def worker(name, call):
            connections.close_all()
            conn = connections["default"]

            def observe(execute, sql, params, many, context):
                if "FOR UPDATE" not in sql.upper() or "ORDERS_ORDER" not in sql.upper():
                    return execute(sql, params, many, context)

                started = time.monotonic()
                pid = conn.connection.get_backend_pid()
                with holder_guard:
                    is_holder = holder[0] is None
                    if is_holder:
                        holder[0] = name
                if not is_holder:
                    second_pid[0] = pid
                    second_lock_attempted.set()

                result = execute(sql, params, many, context)
                query_timings[name] = (
                    datetime.now(timezone.utc).isoformat(),
                    started,
                    time.monotonic(),
                )
                if not is_holder:
                    second_lock_query_finished.set()
                if is_holder:
                    first_lock_acquired.set()
                    if not release_first.wait(15):
                        raise AssertionError("Timed out holding the first Order lock")
                return result

            try:
                with conn.execute_wrapper(observe):
                    start_together.wait(timeout=10)
                    responses[name] = call()
            except BaseException as exc:
                errors.append((name, repr(exc)))
            finally:
                connections.close_all()

        threads = [
            threading.Thread(target=worker, args=(name, call), name=name)
            for name, call in calls
        ]
        for thread in threads:
            thread.start()

        wait_event = None
        try:
            if not first_lock_acquired.wait(10):
                raise AssertionError("No Order SELECT FOR UPDATE was observed")
            if not second_lock_attempted.wait(10):
                raise AssertionError("Second Order lock attempt was not observed")

            deadline = time.monotonic() + 2
            while time.monotonic() < deadline:
                with connection.cursor() as cursor:
                    cursor.execute(
                        "SELECT wait_event_type, wait_event "
                        "FROM pg_stat_activity WHERE pid = %s",
                        [second_pid[0]],
                    )
                    wait_event = cursor.fetchone()
                if wait_event and wait_event[0] == "Lock":
                    break
                time.sleep(0.01)

            # The first transaction is deliberately still holding its row
            # lock. Confirm the second SQL execution cannot finish during
            # that interval; the measured execution time below must include
            # this controlled wait even if pg_stat_activity is momentarily
            # unable to report the backend row.
            time.sleep(0.15)
            if second_lock_query_finished.is_set():
                raise AssertionError("Second Order lock query finished before the first committed")
        finally:
            release_first.set()
            for thread in threads:
                thread.join(20)

        self.assertFalse(any(thread.is_alive() for thread in threads))
        self.assertFalse(errors, errors)
        second_timing = query_timings[next(name for name in query_timings if name != holder[0])]
        elapsed_ms = (second_timing[2] - second_timing[1]) * 1000
        self.assertGreaterEqual(elapsed_ms, 100)
        return responses, query_timings, wait_event, holder[0]

    def _assert_database_state(self, expected_stock):
        state = {
            "status": Order.objects.get(pk=self.order.pk).status,
            "stock": ItemVariantSize.objects.get(pk=self.size.pk).stock,
        }
        self.assertEqual(state, {"status": "PENDING", "stock": expected_stock})
        print("DIRECT_DATABASE_STATE", state)

    def test_same_order_double_place_waits_and_deducts_once(self):
        # Both callers hold an independently-loaded, stale DRAFT instance.
        stale_orders = [Order.objects.get(pk=self.order.pk) for _ in range(2)]
        responses, timings, wait, holder = self._run_lock_race(
            [
                ("place-1", lambda: order_views.place_draft_order(stale_orders[0], {})),
                ("place-2", lambda: order_views.place_draft_order(stale_orders[1], {})),
            ]
        )
        self.assertEqual(sorted(response.status_code for response in responses.values()), [200, 409])
        self._assert_database_state(expected_stock=5)
        print(
            "POSTGRES_LOCK_PROOF",
            {
                "pg_wait": wait,
                "holder": holder,
                "query_ms": {
                    name: {
                        "started_utc": started_utc,
                        "elapsed_ms": round((end - start) * 1000, 2),
                    }
                    for name, (started_utc, start, end) in timings.items()
                },
                "responses": {
                    name: response.status_code
                    for name, response in responses.items()
                },
            },
        )

    def test_agent_place_races_admin_accept(self):
        responses, timings, wait, holder = self._run_lock_race(
            [
                ("agent-place", self._place_view),
                ("admin-accept", self._accept_view),
            ]
        )
        codes = sorted(response.status_code for response in responses.values())
        self.assertEqual(codes[0], 200)
        self.assertIn(codes[1], (400, 409))
        self._assert_database_state(expected_stock=5)
        print(
            "CROSS_ENDPOINT_LOCK_PROOF",
            {
                "pg_wait": wait,
                "holder": holder,
                "query_ms": {
                    name: {
                        "started_utc": started_utc,
                        "elapsed_ms": round((end - start) * 1000, 2),
                    }
                    for name, (started_utc, start, end) in timings.items()
                },
                "responses": {
                    name: {"status": response.status_code, "body": response.data}
                    for name, response in responses.items()
                },
            },
        )

    def test_negative_control_without_order_lock_allows_double_placement(self):
        source = textwrap.dedent(inspect.getsource(order_views.place_draft_order))
        lock_and_recheck = '''order = Order.objects.select_for_update().get(pk=order.pk)
        if order.status != "DRAFT":
            return Response(
                {"error": "This order has already been placed."},
                status=status.HTTP_409_CONFLICT,
            )'''
        self.assertIn(lock_and_recheck, source)
        unsafe_source = source.replace(
            lock_and_recheck, "pass  # negative control: omit Order lock/recheck"
        )
        namespace = dict(order_views.__dict__)
        exec(compile(unsafe_source, "<negative-control>", "exec"), namespace)
        unsafe_place = namespace["place_draft_order"]

        stale_orders = [Order.objects.get(pk=self.order.pk) for _ in range(2)]
        start_together = threading.Barrier(2)
        responses = []
        errors = []

        def worker(order):
            connections.close_all()
            try:
                start_together.wait(timeout=10)
                responses.append(unsafe_place(order, {}).status_code)
            except BaseException as exc:
                errors.append(repr(exc))
            finally:
                connections.close_all()

        threads = [threading.Thread(target=worker, args=(order,)) for order in stale_orders]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join(20)

        self.assertFalse(errors, errors)
        self.assertEqual(sorted(responses), [200, 200])
        self._assert_database_state(expected_stock=0)
        print(
            "NEGATIVE_CONTROL",
            {
                "responses": sorted(responses),
                "stock": ItemVariantSize.objects.get(pk=self.size.pk).stock,
                "status": Order.objects.get(pk=self.order.pk).status,
            },
        )
