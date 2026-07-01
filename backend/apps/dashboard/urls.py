from django.urls import path

from apps.dashboard.views import ActiveTripsView, CompletedTripsView, DashboardStatsView

urlpatterns = [
    path("stats/", DashboardStatsView.as_view(), name="dashboard-stats"),
    path("active-trips/", ActiveTripsView.as_view(), name="dashboard-active-trips"),
    path("completed-trips/", CompletedTripsView.as_view(), name="dashboard-completed-trips"),
]
