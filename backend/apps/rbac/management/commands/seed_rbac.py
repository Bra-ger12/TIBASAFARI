from django.core.management.base import BaseCommand

from apps.rbac.models import Permission, Role, RolePermission


PERMISSIONS = {
    "manage_users": "Manage users",
    "manage_drivers": "Manage drivers",
    "manage_patients": "Manage patients",
    "manage_trips": "Manage trips",
    "assign_driver": "Assign drivers to trips",
    "view_reports": "View reports",
    "view_dashboard": "View admin dashboard",
    "view_assigned_trips": "View assigned trips",
    "update_trip_status": "Update trip status",
    "update_location": "Update driver location",
    "create_trip": "Create trip request",
    "view_own_trips": "View own trips",
    "cancel_trip": "Cancel trip",
    "trip_messages": "Send/view trip chat messages",
    "operations.view_vehicle": "View vehicles",
    "operations.manage_vehicle": "Manage vehicles",
    "accounts.view_user": "View users",
    "rbac.view_permission": "View permissions",
    "rbac.manage_permission": "Manage permissions",
    "rbac.view_role": "View roles",
    "rbac.manage_role": "Manage roles",
    "rbac.view_user_role": "View user role assignments",
    "rbac.assign_role": "Assign roles",
}

ROLES = {
    "ADMIN": {
        "description": "System administrator",
        "permissions": [
            "manage_users",
            "manage_drivers",
            "manage_patients",
            "manage_trips",
            "assign_driver",
            "view_reports",
            "view_dashboard",
            "view_assigned_trips",
            "update_trip_status",
            "update_location",
            "create_trip",
            "view_own_trips",
            "cancel_trip",
            "trip_messages",
            "operations.view_vehicle",
            "operations.manage_vehicle",
            "accounts.view_user",
            "rbac.view_permission",
            "rbac.manage_permission",
            "rbac.view_role",
            "rbac.manage_role",
            "rbac.view_user_role",
            "rbac.assign_role",
        ],
    },
    "DRIVER": {
        "description": "Driver user",
        "permissions": [
            "view_assigned_trips",
            "update_trip_status",
            "update_location",
            "trip_messages",
        ],
    },
    "PATIENT": {
        "description": "Patient user",
        "permissions": ["create_trip", "view_own_trips", "cancel_trip", "trip_messages"],
    },
}


class Command(BaseCommand):
    help = "Seed default RBAC permissions and roles."

    def handle(self, *args, **options):
        permission_objects = {}
        for code, name in PERMISSIONS.items():
            permission, _ = Permission.objects.update_or_create(
                code=code,
                defaults={"name": name},
            )
            permission_objects[code] = permission

        for code, role_data in ROLES.items():
            role, _ = Role.objects.update_or_create(
                code=code,
                defaults={"name": code, "description": role_data["description"]},
            )
            selected_permissions = [
                permission_objects[permission_code]
                for permission_code in role_data["permissions"]
            ]
            role.permissions.set(selected_permissions)
            for permission in selected_permissions:
                RolePermission.objects.get_or_create(role=role, permission=permission)

        self.stdout.write(self.style.SUCCESS("RBAC seed completed."))
