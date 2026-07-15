"""Retroactively fixes any already-existing PATIENT/DRIVER/ADMIN roles
whose permissions were granted by the old, drifted ad hoc signup code
(missing cancel_trip/trip_messages) rather than the canonical catalog —
new signups are already covered going forward by the code changes in the
same commit, but any accounts created before this fix need their role's
permission set corrected too."""
from django.db import migrations


def sync_roles(apps, schema_editor):
    from apps.rbac.catalog import ROLES, sync_role

    Role = apps.get_model("rbac", "Role")
    for code in ROLES:
        if Role.objects.filter(code=code).exists():
            sync_role(code)


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("rbac", "0002_alter_role_name_rolepermission"),
    ]

    operations = [
        migrations.RunPython(sync_roles, noop),
    ]
