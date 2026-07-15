from django.core.management.base import BaseCommand

from apps.rbac.catalog import PERMISSIONS, ROLES, sync_role
from apps.rbac.models import Permission


class Command(BaseCommand):
    help = "Seed default RBAC permissions and roles (see apps.rbac.catalog for the canonical definitions)."

    def handle(self, *args, **options):
        for code, name in PERMISSIONS.items():
            Permission.objects.update_or_create(code=code, defaults={"name": name})

        for code in ROLES:
            sync_role(code)

        self.stdout.write(self.style.SUCCESS("RBAC seed completed."))
