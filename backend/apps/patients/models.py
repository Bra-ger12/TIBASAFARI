import uuid

from django.conf import settings
from django.db import models


class PatientProfile(models.Model):
    class MobilityNeeds(models.TextChoices):
        NONE = "NONE", "None"
        WHEELCHAIR = "WHEELCHAIR", "Wheelchair"
        STRETCHER = "STRETCHER", "Stretcher"
        WALKER_CRUTCHES = "WALKER_CRUTCHES", "Walker / Crutches"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        related_name="patient_profile",
        on_delete=models.CASCADE,
    )
    date_of_birth = models.DateField(null=True, blank=True)
    emergency_contact_name = models.CharField(max_length=150, blank=True)
    emergency_contact_phone = models.CharField(max_length=32, blank=True)
    medical_notes = models.TextField(blank=True)
    mobility_needs = models.CharField(
        max_length=20, choices=MobilityNeeds.choices, default=MobilityNeeds.NONE, blank=True
    )
    oxygen_required = models.BooleanField(default=False)
    medical_escort_required = models.BooleanField(default=False)
    iv_drip_required = models.BooleanField(default=False)
    default_pickup_address = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self) -> str:
        return f"PatientProfile({self.user.email})"


class PatientDocument(models.Model):
    """A medical document (record, prescription, insurance card, etc.)
    uploaded by a patient, viewable by staff on the patient's profile."""

    class DocType(models.TextChoices):
        MEDICAL_RECORD = "MEDICAL_RECORD", "Medical Record"
        INSURANCE_CARD = "INSURANCE_CARD", "Insurance Card"
        PRESCRIPTION = "PRESCRIPTION", "Prescription"
        OTHER = "OTHER", "Other"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        PatientProfile,
        related_name="documents",
        on_delete=models.CASCADE,
    )
    doc_type = models.CharField(
        max_length=30, choices=DocType.choices, default=DocType.MEDICAL_RECORD
    )
    file = models.FileField(upload_to="patient_documents/%Y/%m/")
    description = models.CharField(max_length=255, blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-uploaded_at",)

    def __str__(self) -> str:
        return f"PatientDocument({self.patient_id}, {self.doc_type})"

