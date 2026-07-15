import math

from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from apps.core.geo import haversine_distance_km
from apps.core.responses import success_response
from apps.facilities.models import HealthFacility
from apps.facilities.serializers import (
    HealthFacilityNearbySerializer,
    HealthFacilitySerializer,
)

MAX_SEARCH_RESULTS = 20


class FacilitySearchView(APIView):
    """GET /api/v1/facilities/search/?q=<query>&region=<region>

    Autocomplete-style name search (icontains), optionally narrowed to a
    region. Replaces the Google Places "Select Hospital" picker, which
    needs billing we don't have enabled.
    """

    # Only ever called from patient_app's post-login destination picker
    # (book_ride.dart, facility_search_screen.dart) — IsAuthenticated is the
    # actual intended behavior, declared explicitly rather than relying on
    # DRF's global default so it's clear at a glance, matching every other
    # view in this codebase.
    permission_classes = [IsAuthenticated]

    def get(self, request):
        query = request.query_params.get("q", "").strip()
        region = request.query_params.get("region", "").strip()

        if not query and not region:
            return success_response([], "Provide a search query or region")

        queryset = HealthFacility.objects.filter(is_active=True)
        if query:
            queryset = queryset.filter(name__icontains=query)
        if region:
            queryset = queryset.filter(region__iexact=region)

        facilities = queryset.order_by("name")[:MAX_SEARCH_RESULTS]
        serializer = HealthFacilitySerializer(facilities, many=True)
        return success_response(serializer.data)


class FacilityNearbyView(APIView):
    """GET /api/v1/facilities/nearby/?lat=<lat>&lng=<lng>&radius=<km>

    Distance is computed with the same pure-Python Haversine helper used
    for fare estimation (apps.core.geo) — no PostGIS/geocoding API needed.
    A lat/lng bounding-box pre-filter (indexed) keeps this from scanning
    every row before computing exact distance.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            lat = float(request.query_params["lat"])
            lng = float(request.query_params["lng"])
        except (KeyError, ValueError):
            return success_response(
                [], "lat and lng query params are required and must be numeric"
            )
        try:
            radius_km = float(request.query_params.get("radius", 10))
        except ValueError:
            radius_km = 10.0

        # ~111km per degree of latitude; shrink the longitude window at
        # higher latitudes so the box stays roughly circular.
        lat_delta = radius_km / 111.0
        lng_delta = radius_km / (111.0 * max(math.cos(math.radians(lat)), 0.01))

        candidates = HealthFacility.objects.filter(
            is_active=True,
            latitude__range=(lat - lat_delta, lat + lat_delta),
            longitude__range=(lng - lng_delta, lng + lng_delta),
        )

        nearby = []
        for facility in candidates:
            distance = haversine_distance_km(
                lat, lng, facility.latitude, facility.longitude
            )
            if distance <= radius_km:
                facility.distance_km = round(distance, 2)
                nearby.append(facility)
        nearby.sort(key=lambda f: f.distance_km)

        serializer = HealthFacilityNearbySerializer(nearby, many=True)
        return success_response(serializer.data)
