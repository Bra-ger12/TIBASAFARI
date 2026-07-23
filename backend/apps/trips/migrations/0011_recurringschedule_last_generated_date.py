from django.db import migrations, models


def backfill_last_generated_date(apps, schema_editor):
    # Every existing RecurringSchedule already had its start_date occurrence
    # booked as a Trip by the (already-deployed) perform_create fix — set
    # the cursor to start_date so generate_recurring_trips doesn't re-book
    # that same first occurrence.
    RecurringSchedule = apps.get_model("trips", "RecurringSchedule")
    RecurringSchedule.objects.filter(last_generated_date__isnull=True).update(
        last_generated_date=models.F("start_date")
    )


class Migration(migrations.Migration):

    dependencies = [
        ("trips", "0010_tripassignmentevent"),
    ]

    operations = [
        migrations.AddField(
            model_name="recurringschedule",
            name="last_generated_date",
            field=models.DateField(blank=True, null=True),
        ),
        migrations.RunPython(backfill_last_generated_date, migrations.RunPython.noop),
    ]
