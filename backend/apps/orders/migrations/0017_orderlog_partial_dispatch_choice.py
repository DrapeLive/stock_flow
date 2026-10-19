from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("orders", "0016_orderitem_stock_reserved"),
    ]

    operations = [
        migrations.AlterField(
            model_name="orderlog",
            name="action",
            field=models.CharField(
                choices=[
                    ("ITEM_DELETED", "Item Deleted"),
                    ("ORDER_DELETED", "Order Deleted"),
                    ("ORDER_EDITED", "Order Edited"),
                    ("DISPATCHED", "Dispatched"),
                    ("PARTIAL_DISPATCH", "Partial Dispatch"),
                    ("EDIT_STARTED", "Edit Started"),
                    ("EDIT_SAVED", "Edit Saved"),
                    ("EDIT_CANCELLED", "Edit Cancelled"),
                ],
                max_length=20,
            ),
        ),
    ]
