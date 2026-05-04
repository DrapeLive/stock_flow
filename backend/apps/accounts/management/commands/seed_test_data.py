from pathlib import Path
from django.core.management.base import BaseCommand
from django.core.files import File
from django.contrib.auth import get_user_model
from apps.business.models import Brand
from apps.agents.models import Agent, AgentItem
from apps.customers.models import Customer
from apps.items.models import Item, ItemVariant, ItemVariantSize
from apps.orders.models import Order, OrderItem
import random

from apps.orders.utils import SIZE_MAPPING
from apps.orders.serializers import get_piece_count

User = get_user_model()


class Command(BaseCommand):
    help = "Seed comprehensive test data for admins, agents, customers, items, and orders"

    def handle(self, *args, **kwargs):
        base_dir = Path(__file__).resolve().parent.parent.parent.parent.parent

        # ---- Brands ----
        brands_data = [
            {
                "name": "XL TOWER",
                "phone": "9447447369, 9447744369",
                "email": "xicalicut@gmail.com",
                "address_line1": "Muttanchery",
                "address_line2": "Narikkuni, Calicut - 673585",
                "gst": "",
                "logo_path": "seed_data/xl-tower.png",
            },
            {
                "name": "BN CLOTHING",
                "phone": "",
                "email": "bnclothingclt@gmail.com",
                "address_line1": "Muttancheri (P.O), Narikuni",
                "address_line2": "Kozhikode, Kerala - 673585",
                "gst": "",
                "logo_path": "seed_data/bn-clothing.png",
            },
        ]

        brands = {}
        for brand_data in brands_data:
            name = brand_data["name"]
            if Brand.objects.filter(name=name).exists():
                brands[name] = Brand.objects.get(name=name)
                self.stdout.write(self.style.WARNING(f"Brand already exists: {name}"))
            else:
                logo_path = brand_data.pop("logo_path", None)
                brand = Brand(**brand_data)
                if logo_path:
                    full_path = base_dir / logo_path
                    if full_path.exists():
                        with open(full_path, "rb") as f:
                            brand.logo.save(full_path.name, File(f), save=False)
                brand.save()
                brands[name] = brand
                self.stdout.write(self.style.SUCCESS(f"Created brand: {name}"))

        # ---- Admins ----
        admins_data = [
            {
                "username": "kidsadmin",
                "email": "kidsadmin@example.com",
                "password": "password123",
                "first_name": "Kids",
                "last_name": "Admin",
                "role": "ADMIN",
                "business": "kids",
            },
            {
                "username": "gentsadmin",
                "email": "gentsadmin@example.com",
                "password": "password123",
                "first_name": "Gents",
                "last_name": "Admin",
                "role": "ADMIN",
                "business": "gents",
            },
        ]

        for admin_data in admins_data:
            email = admin_data["email"]
            if User.objects.filter(email=email).exists():
                self.stdout.write(self.style.WARNING(f"Admin already exists: {email}"))
                continue
            password = admin_data.pop("password")
            user = User(**admin_data)
            user.set_password(password)
            user.save()
            # Assign brand based on business type
            if admin_data["business"] == "kids":
                user.brand = brands["XL TOWER"]
            else:
                user.brand = brands["BN CLOTHING"]
            user.save()
            self.stdout.write(self.style.SUCCESS(f"Created admin: {email}"))

        # ---- Agent ----
        agent_email = "agent@example.com"
        if User.objects.filter(email=agent_email).exists():
            self.stdout.write(self.style.WARNING(f"Agent already exists: {agent_email}"))
            agent_user = User.objects.get(email=agent_email)
            agent = agent_user.agent if hasattr(agent_user, 'agent') else None
        else:
            agent_user = User.objects.create_user(
                username="agent",
                email=agent_email,
                password="password123",
                first_name="Test",
                last_name="Agent",
                role="AGENT",
                business="gents",
                brand=brands["BN CLOTHING"],
            )
            agent = Agent.objects.create(user=agent_user, contact="1234567890")
            self.stdout.write(self.style.SUCCESS(f"Created agent: {agent_email}"))

        # ---- Customers ----
        customers_data = [
            {
                "name": "Customer One",
                "address": "123 Main St, Calicut",
                "contact": "9876543210",
                "agent": agent,
            },
            {
                "name": "Customer Two",
                "address": "456 Oak Ave, Calicut",
                "contact": "9876543211",
                "agent": agent,
            },
        ]

        customers = []
        for cust_data in customers_data:
            name = cust_data["name"]
            if Customer.objects.filter(name=name, agent=agent).exists():
                self.stdout.write(self.style.WARNING(f"Customer already exists: {name}"))
                customers.append(Customer.objects.get(name=name, agent=agent))
            else:
                customer = Customer.objects.create(**cust_data)
                customers.append(customer)
                self.stdout.write(self.style.SUCCESS(f"Created customer: {name}"))

        # ---- Items with Variants and Sizes ----
        items_data = []

        for i in range(20):  # create 20 unique items
            items_data.append({
                "name": f"Gents Item {i}",
                "description": "Auto generated",
                "price": random.randint(500, 3000),
                "type": "gents",
                "brand": brands["BN CLOTHING"],
                "num_variants": random.randint(2, 4),
                "image_paths": ["seed_data/test_data/green-shirt.jpg", "seed_data/test_data/pink-shirt.jpg", "seed_data/test_data/white-shirt.jpg"],
            })

        for i in range(20):
            items_data.append({
                "name": f"Kids Item {i}",
                "description": "Auto generated",
                "price": random.randint(300, 2000),
                "type": "kids",
                "brand": brands["XL TOWER"],
                "num_variants": random.randint(2, 3),
                "image_paths": ["seed_data/test_data/white-shirt.jpg", "seed_data/test_data/green-shirt.jpg", "seed_data/test_data/pink-shirt.jpg" ],
            })

        items = []
        for item_data in items_data:
            name = item_data["name"]
            if Item.objects.filter(name=name).exists():
                self.stdout.write(self.style.WARNING(f"Item already exists: {name}"))
                items.append(Item.objects.get(name=name))
                continue

            num_variants = item_data.pop("num_variants")
            image_paths = item_data.pop("image_paths")
            item = Item.objects.create(**item_data)
            items.append(item)
            self.stdout.write(self.style.SUCCESS(f"Created item: {name}"))

            for i in range(num_variants):
                variant = ItemVariant.objects.create(item=item)
                if i < len(image_paths) and image_paths[i]:
                    full_path = base_dir / image_paths[i]
                    if full_path.exists():
                        with open(full_path, "rb") as f:
                            variant.image.save(full_path.name, File(f), save=False)
                            variant.save()

                # Get all individual sizes from SIZE_MAPPING for this item type
                size_groups = SIZE_MAPPING.get(item.type, {})
                individual_sizes = set()
                for size_list in size_groups.values():
                    individual_sizes.update(size_list)

                for size in individual_sizes:
                    ItemVariantSize.objects.create(
                        item_variant=variant,
                        size=size,
                        stock=100
                    )

                self.stdout.write(
                    self.style.SUCCESS(f"  Created variant {i+1} for {name} with {len(individual_sizes)} sizes")
                )

        # ---- Assign Items to Agent ----
        # Only assign gents items since agent's business is "gents"
        for item in items:
            if item.type != "gents":
                continue
            if not AgentItem.objects.filter(agent=agent, item=item).exists():
                AgentItem.objects.create(agent=agent, item=item)
                self.stdout.write(self.style.SUCCESS(f"Assigned item '{item.name}' to agent"))
            else:
                self.stdout.write(self.style.WARNING(f"Item '{item.name}' already assigned to agent"))

        # ---- Orders ----
        if Order.objects.filter(agent=agent).exists():
            self.stdout.write(self.style.WARNING("Orders already exist for agent, skipping order creation"))
        else:
            gents_size_groups = list(SIZE_MAPPING["gents"].keys())

            # Preload everything (IMPORTANT)
            items = list(Item.objects.prefetch_related("variants"))
            customers = list(Customer.objects.filter(agent=agent))

            gents_items = [item for item in items if item.type == "gents"]

            # Cache variants to avoid repeated queries
            item_variants_map = {
                item.id: list(item.variants.all())
                for item in items
            }

            # ---- Create Orders in Bulk ----
            NUM_ORDERS = 1000  # keep small here (you said 1000 elsewhere)

            # Only create orders for gents items (agent's business type)
            orders_to_create = []
            for _ in range(NUM_ORDERS):
                orders_to_create.append(
                    Order(
                        customer=random.choice(customers),
                        agent=agent,
                        status=random.choices(
                            ["PENDING", "PACKED", "DISPATCHED"],
                            weights=[60, 25, 15]
                        )[0],
                    )
                )

            orders = Order.objects.bulk_create(orders_to_create)

            # ---- Create OrderItems in Bulk ----
            order_items_to_create = []

            for order in orders:
                num_items = random.randint(20, 25)

                # Only use gents items since agent is gents business
                selected_items = random.choices(gents_items, k=num_items)

                for item in selected_items:
                    variants = item_variants_map[item.id]
                    if not variants:
                        continue

                    variant = random.choice(variants)

                    size_group = random.choice(gents_size_groups)
                    available_sizes = SIZE_MAPPING["gents"][size_group]
                    size = random.choice(available_sizes)

                    quantity = random.randint(1, 5)
                    # packed_quantity should be in pieces (sets * piece_count)
                    piece_count = get_piece_count(size_group, item.type)

                    if order.status in ["PACKED", "DISPATCHED"]:
                        packed_quantity = quantity * piece_count
                    else:
                        packed_quantity = 0

                    order_items_to_create.append(
                        OrderItem(
                            order=order,
                            item=item,
                            variant=variant,
                            item_type=item.type,
                            item_name=item.name,
                            item_price=item.price,
                            variant_image=variant.image.url if variant.image else "",
                            size_group=size_group,
                            size=size,
                            quantity=quantity,
                            packed_quantity=packed_quantity,
                        )
                    )

            # ---- Bulk Insert in Chunks (VERY IMPORTANT) ----
            BATCH_SIZE = 2000

            for i in range(0, len(order_items_to_create), BATCH_SIZE):
                OrderItem.objects.bulk_create(order_items_to_create[i:i + BATCH_SIZE])


            self.stdout.write(
                self.style.SUCCESS(f"Created {len(orders)} orders with {len(order_items_to_create)} items")
            )
        self.stdout.write(self.style.SUCCESS("\n" + "=" * 50))
        self.stdout.write(self.style.SUCCESS("Seed data creation complete!"))
        self.stdout.write(self.style.SUCCESS("=" * 50))
