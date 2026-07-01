import django.db.models.deletion
import uuid

from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("trips", "0001_initial"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        # 1. Add RecurringSchedule model
        migrations.CreateModel(
            name="RecurringSchedule",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("patient", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="recurring_schedules", to=settings.AUTH_USER_MODEL)),
                ("pickup_address", models.CharField(max_length=255)),
                ("destination_address", models.CharField(max_length=255)),
                ("pickup_latitude", models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ("pickup_longitude", models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ("destination_latitude", models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ("destination_longitude", models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ("pickup_time", models.TimeField()),
                ("frequency", models.CharField(choices=[("DAILY","Daily"),("WEEKLY","Weekly"),("BIWEEKLY","Every Two Weeks"),("MONTHLY","Monthly")], max_length=20)),
                ("days_of_week", models.JSONField(blank=True, default=list)),
                ("special_requirements", models.TextField(blank=True)),
                ("is_active", models.BooleanField(default=True)),
                ("start_date", models.DateField()),
                ("end_date", models.DateField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={"ordering": ("-created_at",)},
        ),

        # 2. Add new fields to Trip
        migrations.AddField(
            model_name="trip",
            name="recurring_schedule",
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="trips", to="trips.recurringschedule"),
        ),
        migrations.AddField(
            model_name="trip",
            name="mobility_aid",
            field=models.CharField(
                choices=[("NONE","None"),("MANUAL_WC","Manual Wheelchair"),("POWER_WC","Power Wheelchair"),("STRETCHER","Stretcher"),("AMBULATORY","Ambulatory (walking)")],
                default="NONE", max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="trip",
            name="service_level",
            field=models.CharField(
                choices=[("CURB","Curb-to-Curb"),("DOOR","Door-to-Door"),("DTD","Door-Through-Door")],
                default="CURB", max_length=10,
            ),
        ),
        migrations.AddField(
            model_name="trip",
            name="oxygen_required",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="trip",
            name="bariatric",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="trip",
            name="num_attendants",
            field=models.PositiveSmallIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="trip",
            name="distance_km",
            field=models.DecimalField(blank=True, decimal_places=3, max_digits=8, null=True),
        ),
        migrations.AddField(
            model_name="trip",
            name="duration_minutes",
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="trip",
            name="estimated_fare",
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True),
        ),
        migrations.AddField(
            model_name="trip",
            name="arrived_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
