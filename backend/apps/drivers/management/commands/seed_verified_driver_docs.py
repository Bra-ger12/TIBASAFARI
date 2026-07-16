from django.contrib.auth import get_user_model
from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand

from apps.drivers.models import DriverDocument, DriverProfile

User = get_user_model()

REQUIRED_DOC_TYPES = [
    DriverDocument.DocType.LICENSE,
    DriverDocument.DocType.INSURANCE,
    DriverDocument.DocType.VEHICLE_REGISTRATION,
]


class Command(BaseCommand):
    help = (
        "Create VERIFIED placeholder DriverDocument rows (license, insurance, "
        "vehicle registration) for driver test accounts, so trip assignment "
        "isn't blocked on compliance docs while testing. Not for real drivers "
        "in production use — the file content is a placeholder, not a real "
        "scanned document."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "emails",
            nargs="*",
            help="Driver account emails to seed. Omit to seed every driver profile.",
        )

    def handle(self, *args, **options):
        emails = options["emails"]
        profiles = DriverProfile.objects.select_related("user")
        if emails:
            profiles = profiles.filter(user__email__in=emails)

        if not profiles.exists():
            self.stdout.write(self.style.WARNING("No matching driver profiles found."))
            return

        for profile in profiles:
            for doc_type in REQUIRED_DOC_TYPES:
                doc, created = DriverDocument.objects.get_or_create(
                    driver=profile,
                    doc_type=doc_type,
                    defaults={"status": DriverDocument.Status.VERIFIED},
                )
                if not created and doc.status != DriverDocument.Status.VERIFIED:
                    doc.status = DriverDocument.Status.VERIFIED
                if not doc.file:
                    doc.file.save(
                        f"{doc_type.lower()}_placeholder.txt",
                        ContentFile(b"seeded placeholder document"),
                        save=False,
                    )
                doc.save()
            self.stdout.write(
                self.style.SUCCESS(f"Verified all docs for {profile.user.email}")
            )
