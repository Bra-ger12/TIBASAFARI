"""Geospatial math utilities — pure Python, no external geocoding/distance
API calls (keeps cost down and avoids a network dependency in the fare
estimation path)."""
import math

EARTH_RADIUS_KM = 6371.0088  # IUGG mean Earth radius


def haversine_distance_km(lat1, lng1, lat2, lng2) -> float:
    """Great-circle distance between two lat/lng points, in kilometers."""
    lat1, lng1, lat2, lng2 = (float(v) for v in (lat1, lng1, lat2, lng2))
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)

    a = (
        math.sin(d_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return EARTH_RADIUS_KM * c
