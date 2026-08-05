from django.db import migrations


PATIENT_PERMISSIONS = {
    "create_trip": "Create trip request",
    "view_own_trips": "View own trips",
    "cancel_trip": "Cancel trip",
    "trip_messages": "Send/view trip chat messages",
    "view_own_profile": "View own profile",
    "view_notifications": "View notifications",
}


def backfill_patient_roles(apps, schema_editor):
    PatientProfile = apps.get_model("patients", "PatientProfile")
    Permission = apps.get_model("rbac", "Permission")
    Role = apps.get_model("rbac", "Role")
    RolePermission = apps.get_model("rbac", "RolePermission")
    UserRole = apps.get_model("rbac", "UserRole")

    patient_role, _ = Role.objects.get_or_create(
        code="PATIENT",
        defaults={"name": "PATIENT", "description": "Patient user"},
    )

    permissions = []
    for code, name in PATIENT_PERMISSIONS.items():
        permission, _ = Permission.objects.get_or_create(
            code=code,
            defaults={"name": name},
        )
        permissions.append(permission)
        RolePermission.objects.get_or_create(role=patient_role, permission=permission)

    patient_role.permissions.add(*permissions)

    patient_user_ids = PatientProfile.objects.values_list("user_id", flat=True)
    for user_id in patient_user_ids.iterator():
        UserRole.objects.get_or_create(user_id=user_id, role=patient_role)


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("rbac", "0003_sync_role_permissions"),
        ("patients", "0003_patientdocument"),
    ]

    operations = [
        migrations.RunPython(backfill_patient_roles, noop),
    ]
