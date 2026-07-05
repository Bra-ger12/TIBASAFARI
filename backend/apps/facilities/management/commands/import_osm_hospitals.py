import json
import time
import urllib.error
import urllib.parse
import urllib.request

from django.core.management.base import BaseCommand, CommandError

from apps.facilities.models import HealthFacility

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# amenity=hospital/clinic/doctors/pharmacy covers everything OSM tags for
# health facilities in Tanzania directly on the `amenity` key; finer-grained
# types (health_center, dispensary) are inferred from the `healthcare` tag
# or Swahili facility names in _map_facility_type() below.
OVERPASS_QUERY = """
[out:json][timeout:{timeout}];
area["ISO3166-1"="TZ"][admin_level=2]->.tz;
(
  node["amenity"~"^(hospital|clinic|doctors|pharmacy)$"](area.tz);
  way["amenity"~"^(hospital|clinic|doctors|pharmacy)$"](area.tz);
);
out center tags;
"""


class Command(BaseCommand):
    help = (
        "One-time import of Tanzanian hospitals/clinics/pharmacies from the "
        "free OpenStreetMap Overpass API (no key or billing required)."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--timeout",
            type=int,
            default=180,
            help="Overpass query + HTTP timeout in seconds (default: 180)",
        )

    def handle(self, *args, **options):
        timeout = options["timeout"]
        self.stdout.write("Querying Overpass API for Tanzania health facilities...")
        elements = self._fetch_elements(timeout)
        self.stdout.write(f"Received {len(elements)} elements from OSM.")

        created = 0
        already_existed = 0
        skipped = 0

        for element in elements:
            tags = element.get("tags") or {}
            name = (tags.get("name") or "").strip()
            if not name:
                skipped += 1
                continue

            lat, lng = self._coords(element)
            if lat is None or lng is None:
                skipped += 1
                continue

            osm_id = f"{element['type']}/{element['id']}"
            region = (tags.get("addr:region") or tags.get("is_in:region") or "").strip()
            district = (
                tags.get("addr:district") or tags.get("is_in:district") or ""
            ).strip()

            _, was_created = HealthFacility.objects.get_or_create(
                osm_id=osm_id,
                defaults={
                    "name": name,
                    "facility_type": self._map_facility_type(tags),
                    "region": region,
                    "district": district,
                    "latitude": lat,
                    "longitude": lng,
                },
            )
            if was_created:
                created += 1
            else:
                already_existed += 1

            if (created + already_existed) % 200 == 0:
                self.stdout.write(f"  ...{created + already_existed} processed")

        self.stdout.write(
            self.style.SUCCESS(
                f"Import complete: {created} created, {already_existed} already "
                f"existed, {skipped} skipped (unnamed or missing coordinates)."
            )
        )

    def _fetch_elements(self, timeout, retried=False):
        query = OVERPASS_QUERY.format(timeout=timeout)
        data = urllib.parse.urlencode({"data": query}).encode("utf-8")
        # Overpass returns 406 Not Acceptable for the default
        # "Python-urllib/x.y" User-Agent, so identify ourselves explicitly.
        request = urllib.request.Request(
            OVERPASS_URL,
            data=data,
            method="POST",
            headers={"User-Agent": "TibaSafari-NEMT/1.0 (health facility import)"},
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                payload = json.loads(response.read().decode("utf-8"))
                return payload.get("elements", [])
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            if retried:
                raise CommandError(
                    f"Overpass API request failed after retry: {exc}"
                ) from exc
            self.stdout.write(
                self.style.WARNING(f"Overpass request failed ({exc}); retrying once in 5s...")
            )
            time.sleep(5)
            return self._fetch_elements(timeout, retried=True)

    @staticmethod
    def _coords(element):
        if element["type"] == "node":
            return element.get("lat"), element.get("lon")
        center = element.get("center") or {}
        return center.get("lat"), center.get("lon")

    @staticmethod
    def _map_facility_type(tags):
        healthcare = (tags.get("healthcare") or "").lower()
        amenity = (tags.get("amenity") or "").lower()
        name = (tags.get("name") or "").lower()

        if amenity == "hospital" or healthcare == "hospital":
            return HealthFacility.FacilityType.HOSPITAL
        if healthcare in ("centre", "health_center", "health_centre") or "kituo cha afya" in name:
            return HealthFacility.FacilityType.HEALTH_CENTER
        if healthcare == "dispensary" or "zahanati" in name:
            return HealthFacility.FacilityType.DISPENSARY
        if amenity == "pharmacy" or healthcare == "pharmacy":
            return HealthFacility.FacilityType.PHARMACY
        return HealthFacility.FacilityType.CLINIC
