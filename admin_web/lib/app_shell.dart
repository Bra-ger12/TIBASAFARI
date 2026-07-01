import 'package:flutter/material.dart';

import 'models/models.dart';
import 'screens/billing_invoices_screen.dart';
import 'services/auth_storage.dart';
import 'screens/booking_detail_screen.dart';
import 'screens/bookings_all_screen.dart';
import 'screens/bookings_pending_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/driver_profile_screen.dart';
import 'screens/drivers_list_screen.dart';
import 'screens/invoice_detail_screen.dart';
import 'screens/notifications_broadcast_screen.dart';
import 'screens/patient_profile_screen.dart';
import 'screens/patients_list_screen.dart';
import 'screens/payments_pending_screen.dart';
import 'screens/reports_drivers_screen.dart';
import 'screens/reports_revenue_screen.dart';
import 'screens/reports_trips_screen.dart';
import 'screens/settings_config_screen.dart';
import 'screens/settings_profile_screen.dart';
import 'screens/trip_detail_screen.dart';
import 'screens/trips_active_screen.dart';
import 'screens/trips_all_screen.dart';
import 'screens/vehicle_form_screen.dart';
import 'screens/vehicles_list_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'widgets/nav.dart';
import 'widgets/sidebar.dart';
import 'widgets/status_badge.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final NavState _nav = NavState();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  AdminUser? _admin;

  @override
  void initState() {
    super.initState();
    _nav.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!AuthStorage.isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _loadAdmin();
      }
    });
  }

  Future<void> _loadAdmin() async {
    try {
      final res = await ApiService.get('/auth/profile/');
      if (!mounted) return;
      setState(() => _admin = AdminUser.fromJson(res));
    } catch (_) {}
  }

  void _logout() {
    AuthStorage.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Widget _screenFor(ViewKey view) {
    switch (view) {
      case ViewKey.dashboard:
        return DashboardScreen(nav: _nav);
      case ViewKey.bookingsPending:
        return BookingsPendingScreen(nav: _nav);
      case ViewKey.bookingsAll:
        return BookingsAllScreen(nav: _nav);
      case ViewKey.bookingDetail:
        return BookingDetailScreen(nav: _nav);
      case ViewKey.tripsActive:
        return TripsActiveScreen(nav: _nav);
      case ViewKey.tripsAll:
        return TripsAllScreen(nav: _nav);
      case ViewKey.tripDetail:
        return TripDetailScreen(nav: _nav);
      case ViewKey.patientsList:
        return PatientsListScreen(nav: _nav);
      case ViewKey.patientProfile:
        return PatientProfileScreen(nav: _nav);
      case ViewKey.driversList:
        return DriversListScreen(nav: _nav);
      case ViewKey.driverProfile:
        return DriverProfileScreen(nav: _nav);
      case ViewKey.vehiclesList:
        return VehiclesListScreen(nav: _nav);
      case ViewKey.vehicleAdd:
        return VehicleFormScreen(nav: _nav, isEdit: false);
      case ViewKey.vehicleEdit:
        return VehicleFormScreen(nav: _nav, isEdit: true);
      case ViewKey.billingInvoices:
        return BillingInvoicesScreen(nav: _nav);
      case ViewKey.invoiceDetail:
        return InvoiceDetailScreen(nav: _nav);
      case ViewKey.paymentsPending:
        return PaymentsPendingScreen(nav: _nav);
      case ViewKey.reportsTrips:
        return ReportsTripsScreen(nav: _nav);
      case ViewKey.reportsDrivers:
        return ReportsDriversScreen(nav: _nav);
      case ViewKey.reportsRevenue:
        return ReportsRevenueScreen(nav: _nav);
      case ViewKey.notificationsBroadcast:
        return const NotificationsBroadcastScreen();
      case ViewKey.settingsProfile:
        return const SettingsProfileScreen();
      case ViewKey.settingsConfig:
        return const SettingsConfigScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: MediaQuery.of(context).size.width < 1024
          ? Drawer(
              child: SafeArea(child: AppSidebar(nav: _nav, isMobile: true)),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1024;
          return Column(
            children: [
              Container(
                height: 56,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    if (!wide)
                      IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                      ),
                    if (wide) const SizedBox(width: 8),
                    const Text(
                      'Tiba Safari',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () =>
                          _nav.navigate(ViewKey.notificationsBroadcast),
                    ),
                    const SizedBox(width: 8),
                    AvatarCircle(name: _admin?.name ?? 'Admin', size: 32),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.logout, size: 18),
                      tooltip: 'Sign out',
                      onPressed: _logout,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          AppSidebar(nav: _nav),
                          Expanded(child: _content()),
                        ],
                      )
                    : _content(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _content() {
    return Container(
      color: AppTheme.background,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: _screenFor(_nav.view),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Center(
              child: Text(
                '(c) ${DateTime.now().year} Tiba Safari - Medical Transport Operations - Dar es Salaam, Tanzania - v1.0.0',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
