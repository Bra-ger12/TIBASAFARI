import uuid

from django.db import models


class HealthFacility(models.Model):
    """A hospital/clinic/pharmacy a patient can pick as a trip destination.

    Seeded from OpenStreetMap (see management/commands/import_osm_hospitals.py)
    instead of the Google Places API, which requires billing we don't have
    enabled. `osm_id` (e.g. "node/123456") is the import's dedup key — OSM
    facility names aren't unique across regions, but the OSM element id is
    stable across re-imports.
    """

    class FacilityType(models.TextChoices):
        HOSPITAL = "HOSPITAL", "Hospital"
        HEALTH_CENTER = "HEALTH_CENTER", "Health Center"
        DISPENSARY = "DISPENSARY", "Dispensary"
        CLINIC = "CLINIC", "Clinic"
        PHARMACY = "PHARMACY", "Pharmacy"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    facility_type = models.CharField(
        max_length=20, choices=FacilityType.choices, default=FacilityType.HOSPITAL
    )
    region = models.CharField(max_length=100, blank=True)
    district = models.CharField(max_length=100, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    osm_id = models.CharField(
        max_length=32,
        blank=True,
        unique=True,
        null=True,
        help_text="OSM element reference, e.g. 'node/123456' or 'way/123456'.",
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("name",)
        indexes = [
            models.Index(fields=("name",), name="facility_name_idx"),
            models.Index(fields=("region",), name="facility_region_idx"),
            models.Index(fields=("latitude", "longitude"), name="facility_latlng_idx"),
        ]
        verbose_name_plural = "health facilities"

    def __str__(self) -> str:
        return f"{self.name} ({self.get_facility_type_display()})"
