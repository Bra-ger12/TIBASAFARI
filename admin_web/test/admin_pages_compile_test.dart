import 'package:admin_web/screens/billing_invoices_screen.dart';
import 'package:admin_web/screens/booking_detail_screen.dart';
import 'package:admin_web/screens/bookings_all_screen.dart';
import 'package:admin_web/screens/bookings_pending_screen.dart';
import 'package:admin_web/screens/dashboard_screen.dart';
import 'package:admin_web/screens/driver_profile_screen.dart';
import 'package:admin_web/screens/drivers_list_screen.dart';
import 'package:admin_web/screens/invoice_detail_screen.dart';
import 'package:admin_web/screens/notifications_broadcast_screen.dart';
import 'package:admin_web/screens/patient_profile_screen.dart';
import 'package:admin_web/screens/patients_list_screen.dart';
import 'package:admin_web/screens/reports_drivers_screen.dart';
import 'package:admin_web/screens/reports_revenue_screen.dart';
import 'package:admin_web/screens/reports_trips_screen.dart';
import 'package:admin_web/screens/settings_config_screen.dart';
import 'package:admin_web/screens/settings_profile_screen.dart';
import 'package:admin_web/screens/trip_detail_screen.dart';
import 'package:admin_web/screens/trips_active_screen.dart';
import 'package:admin_web/screens/trips_all_screen.dart';
import 'package:admin_web/screens/vehicle_form_screen.dart';
import 'package:admin_web/screens/vehicles_list_screen.dart';
import 'package:admin_web/widgets/nav.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all admin pages are wired and instantiable', () {
    final nav = NavState();
    final pages = [
      DashboardScreen(nav: nav),
      BookingsPendingScreen(nav: nav),
      BookingsAllScreen(nav: nav),
      BookingDetailScreen(nav: nav),
      TripsActiveScreen(nav: nav),
      TripsAllScreen(nav: nav),
      TripDetailScreen(nav: nav),
      PatientsListScreen(nav: nav),
      PatientProfileScreen(nav: nav),
      DriversListScreen(nav: nav),
      DriverProfileScreen(nav: nav),
      VehiclesListScreen(nav: nav),
      VehicleFormScreen(nav: nav, isEdit: false),
      VehicleFormScreen(nav: nav, isEdit: true),
      BillingInvoicesScreen(nav: nav),
      InvoiceDetailScreen(nav: nav),
      ReportsTripsScreen(nav: nav),
      ReportsDriversScreen(nav: nav),
      ReportsRevenueScreen(nav: nav),
      NotificationsBroadcastScreen(),
      SettingsProfileScreen(),
      SettingsConfigScreen(),
    ];

    expect(pages, hasLength(22));
  });
}
