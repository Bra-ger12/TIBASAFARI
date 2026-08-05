import os

from django.core.management.base import BaseCommand
from django.db import transaction

from apps.accounts.models import User


class Command(BaseCommand):
    help = (
        "Create or upgrade an admin account from environment variables or "
        "CLI options. If no email/password is supplied, the command exits."
    )

    def add_arguments(self, parser):
        parser.add_argument("--email", default=os.getenv("ADMIN_BOOTSTRAP_EMAIL", ""))
        parser.add_argument(
            "--password", default=os.getenv("ADMIN_BOOTSTRAP_PASSWORD", "")
        )
        parser.add_argument(
            "--full-name",
            dest="full_name",
            default=os.getenv("ADMIN_BOOTSTRAP_FULL_NAME", ""),
        )
        parser.add_argument("--phone-number", default=os.getenv("ADMIN_BOOTSTRAP_PHONE", ""))

    @transaction.atomic
    def handle(self, *args, **options):
        email = (options["email"] or "").strip().lower()
        password = options["password"] or ""
        full_name = (options["full_name"] or "").strip()
        phone_number = (options["phone_number"] or "").strip()

        if not email or not password:
            self.stdout.write("Admin bootstrap skipped: missing email or password.")
            return

        user = User.objects.filter(email__iexact=email).first()
        created = user is None
        if created:
            user = User.objects.create_user(
                email=email,
                password=password,
                full_name=full_name or email.split("@")[0],
                phone_number=phone_number,
                status=User.Status.ACTIVE,
                is_active=True,
                is_staff=True,
                is_superuser=True,
            )
        else:
            if full_name:
                user.full_name = full_name
            if phone_number:
                user.phone_number = phone_number
            user.set_password(password)
            user.status = User.Status.ACTIVE
            user.is_active = True
            user.is_staff = True
            user.is_superuser = True
            user.save()

        action = "Created" if created else "Updated"
        self.stdout.write(
            self.style.SUCCESS(
                f"{action} admin bootstrap account for {user.email}."
            )
        )
