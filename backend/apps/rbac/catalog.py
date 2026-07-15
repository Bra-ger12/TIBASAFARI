"""Canonical RBAC permission/role definitions.

This is the single source of truth for what each role grants, used both
by the `seed_rbac` management command AND by the ad hoc role lookups
performed at patient/driver signup (apps.patients.services,
apps.drivers.serializers). Previously those two paths defined the PATIENT
and DRIVER permission sets independently and had drifted apart — signup
granted patients create_trip/view_own_trips/view_own_profile/
view_notifications but NOT cancel_trip or trip_messages, and granted
drivers view_assigned_trips/update_trip_status/update_location but NOT
trip_messages — while seed_rbac (never run automatically on deploy)
had the missing pieces. Every real patient/driver account signed up
before this fix could not cancel a trip or use in-app chat. Routing both
paths through sync_role() here means they can never diverge again, and
new-permission changes only need to happen in one place.
"""
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
    "view_own_profile": "View own profile",
    "view_notifications": "View notifications",
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
        "permissions": [
            "create_trip",
            "view_own_trips",
            "cancel_trip",
            "trip_messages",
            "view_own_profile",
            "view_notifications",
        ],
    },
}


def sync_role(code: str) -> Role:
    """get_or_creates the Role row and makes its permission set exactly
    match the canonical definition above — self-healing any drift, safe
    to call every time a role is looked up (not just once at first
    creation)."""
    role_data = ROLES[code]
    role, _ = Role.objects.get_or_create(
        code=code,
        defaults={"name": code, "description": role_data["description"]},
    )

    permissions = []
    for perm_code in role_data["permissions"]:
        permission, _ = Permission.objects.get_or_create(
            code=perm_code,
            defaults={"name": PERMISSIONS[perm_code]},
        )
        permissions.append(permission)

    role.permissions.set(permissions)
    for permission in permissions:
        RolePermission.objects.get_or_create(role=role, permission=permission)

    return role
