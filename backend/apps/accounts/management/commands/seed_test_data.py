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
        items_data = [
            {
                "name": "Gents Premium Suit",
                "description": "High-quality gents suit with premium fabric",
                "price": 2500.00,
                "type": "gents",
                "brand": brands["BN CLOTHING"],
                "num_variants": 3,
                "image_paths": ["seed_data/test_data/green-shirt.jpg", "seed_data/test_data/pink-shirt.jpg", "seed_data/test_data/white-shirt.jpg"],
            },
            {
                "name": "Kids Designer Wear",
                "description": "Stylish and comfortable kids clothing",
                "price": 1200.00,
                "type": "kids",
                "brand": brands["XL TOWER"],
                "num_variants": 2,
                "image_paths": [ "seed_data/test_data/white-shirt.jpg", "seed_data/test_data/pink-shirt.jpg"],
            },
        ]

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

                if item.type == "gents":
                    sizes = ["S", "M,L,XL", "XXL"]
                else:
                    sizes = ["20-24", "26-30", "32-36", "38"]

                for size in sizes:
                    ItemVariantSize.objects.create(
                        item_variant=variant,
                        size=size,
                        stock=100
                    )

                self.stdout.write(
                    self.style.SUCCESS(f"  Created variant {i+1} for {name} with {len(sizes)} sizes")
                )

        # ---- Assign Items to Agent ----
        for item in items:
            if not AgentItem.objects.filter(agent=agent, item=item).exists():
                AgentItem.objects.create(agent=agent, item=item)
                self.stdout.write(self.style.SUCCESS(f"Assigned item '{item.name}' to agent"))
            else:
                self.stdout.write(self.style.WARNING(f"Item '{item.name}' already assigned to agent"))

        # ---- Orders ----
        if Order.objects.filter(agent=agent).exists():
            self.stdout.write(self.style.WARNING("Orders already exist for agent, skipping order creation"))
        else:
            order_statuses = ["PENDING"] * 5 + ["DISPATCHED"] * 3 + ["PACKED"] * 2
            random.shuffle(order_statuses)

            gents_sizes = ["S", "M,L,XL", "XXL"]
            kids_sizes = ["20-24", "26-30", "32-36", "38"]

            for i, status in enumerate(order_statuses, 1):
                customer = random.choice(customers)
                order = Order.objects.create(
                    customer=customer,
                    agent=agent,
                    status=status,
                )

                num_items = random.randint(1, 2)
                order_items = random.sample(items, min(num_items, len(items)))

                for item in order_items:
                    variant = random.choice(item.variants.all())
                    if item.type == "gents":
                        size_str = random.choice(gents_sizes)
                    else:
                        size_str = random.choice(kids_sizes)

                    quantity = random.randint(1, 5)
                    packed_quantity = quantity if status in ["PACKED", "DISPATCHED"] else 0

                    OrderItem.objects.create(
                        order=order,
                        item=item,
                        variant=variant,
                        size_group=size_str,
                        item_type=item.type,
                        item_name=item.name,
                        item_price=item.price,
                        variant_image=variant.image.url if variant.image else "",
                        size=size_str,
                        quantity=quantity,
                        packed_quantity=packed_quantity,
                    )

                self.stdout.write(
                    self.style.SUCCESS(f"Created order #{order.id} ({status}) for {customer.name}")
                )

        self.stdout.write(self.style.SUCCESS("\n" + "=" * 50))
        self.stdout.write(self.style.SUCCESS("Seed data creation complete!"))
        self.stdout.write(self.style.SUCCESS("=" * 50))
