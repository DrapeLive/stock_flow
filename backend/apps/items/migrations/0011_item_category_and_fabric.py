from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("items", "0010_item_catalog_updated_at_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="item",
            name="category",
            field=models.CharField(blank=True, max_length=100),
        ),
        migrations.AddField(
            model_name="item",
            name="fabric",
            field=models.CharField(blank=True, max_length=150),
        ),
        migrations.CreateModel(
            name="ItemCategory",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("name", models.CharField(max_length=100, unique=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
            ],
            options={"ordering": ["name"]},
        ),
    ]
