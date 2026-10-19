import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("orders", "0017_orderlog_partial_dispatch_choice"),
    ]

    operations = [
        migrations.AddField(
            model_name="order",
            name="split_from",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="split_orders",
                to="orders.order",
            ),
        ),
    ]
