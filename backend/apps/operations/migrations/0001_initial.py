import uuid
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="Vehicle",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        default=uuid.uuid4,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                ("registration_number", models.CharField(max_length=32, unique=True)),
                ("make", models.CharField(max_length=80)),
                ("model", models.CharField(max_length=80)),
                ("year", models.PositiveIntegerField()),
                ("capacity", models.PositiveIntegerField(default=4)),
                ("has_wheelchair_access", models.BooleanField(default=False)),
                (
                    "status",
                    models.CharField(
                        choices=[
                            ("available", "Available"),
                            ("in_service", "In Service"),
                            ("maintenance", "Maintenance"),
                            ("inactive", "Inactive"),
                        ],
                        default="available",
                        max_length=24,
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={"ordering": ("registration_number",)},
        ),
    ]
