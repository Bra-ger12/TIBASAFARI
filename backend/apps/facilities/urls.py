from django.urls import path

from apps.facilities.views import FacilityNearbyView, FacilitySearchView

urlpatterns = [
    path("search/", FacilitySearchView.as_view(), name="facility-search"),
    path("nearby/", FacilityNearbyView.as_view(), name="facility-nearby"),
]
