from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("orders", "0015_order_previous_edit_status"),
    ]

    operations = [
        migrations.AddField(
            model_name="orderitem",
            name="stock_reserved",
            field=models.BooleanField(default=False),
        ),
    ]
