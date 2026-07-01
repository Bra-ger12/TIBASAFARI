import 'package:flutter/material.dart';

class NavItem {
  final IconData icon;
  final String label;
  final ViewKey key;

  const NavItem({required this.icon, required this.label, required this.key});
}

class NavSection {
  final String title;
  final List<NavItem> items;

  const NavSection({required this.title, required this.items});
}

enum ViewKey {
  dashboard,
  bookingsPending,
  bookingsAll,
  bookingDetail,
  tripsActive,
  tripsAll,
  tripDetail,
  patientsList,
  patientProfile,
  driversList,
  driverProfile,
  vehiclesList,
  vehicleAdd,
  vehicleEdit,
  billingInvoices,
  invoiceDetail,
  paymentsPending,
  reportsTrips,
  reportsDrivers,
  reportsRevenue,
  notificationsBroadcast,
  settingsProfile,
  settingsConfig,
}

final List<NavSection> navSections = [
  NavSection(
    title: 'Main',
    items: [
      const NavItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        key: ViewKey.dashboard,
      ),
    ],
  ),
  NavSection(
    title: 'Bookings',
    items: [
      const NavItem(
        icon: Icons.pending_rounded,
        label: 'Pending',
        key: ViewKey.bookingsPending,
      ),
      const NavItem(
        icon: Icons.list_rounded,
        label: 'All Bookings',
        key: ViewKey.bookingsAll,
      ),
    ],
  ),
  NavSection(
    title: 'Trips',
    items: [
      const NavItem(
        icon: Icons.directions_car_rounded,
        label: 'Active Trips',
        key: ViewKey.tripsActive,
      ),
      const NavItem(
        icon: Icons.history_rounded,
        label: 'All Trips',
        key: ViewKey.tripsAll,
      ),
    ],
  ),
  NavSection(
    title: 'Management',
    items: [
      const NavItem(
        icon: Icons.people_rounded,
        label: 'Patients',
        key: ViewKey.patientsList,
      ),
      const NavItem(
        icon: Icons.person_rounded,
        label: 'Drivers',
        key: ViewKey.driversList,
      ),
      const NavItem(
        icon: Icons.directions_car_rounded,
        label: 'Vehicles',
        key: ViewKey.vehiclesList,
      ),
    ],
  ),
  NavSection(
    title: 'Finance',
    items: [
      const NavItem(
        icon: Icons.receipt_rounded,
        label: 'Invoices',
        key: ViewKey.billingInvoices,
      ),
      const NavItem(
        icon: Icons.hourglass_top_rounded,
        label: 'Pending Payments',
        key: ViewKey.paymentsPending,
      ),
    ],
  ),
  NavSection(
    title: 'Reports',
    items: [
      const NavItem(
        icon: Icons.bar_chart_rounded,
        label: 'Trips Report',
        key: ViewKey.reportsTrips,
      ),
      const NavItem(
        icon: Icons.people_rounded,
        label: 'Drivers Report',
        key: ViewKey.reportsDrivers,
      ),
      const NavItem(
        icon: Icons.attach_money_rounded,
        label: 'Revenue',
        key: ViewKey.reportsRevenue,
      ),
    ],
  ),
  NavSection(
    title: 'Settings',
    items: [
      const NavItem(
        icon: Icons.notifications_rounded,
        label: 'Notifications',
        key: ViewKey.notificationsBroadcast,
      ),
      const NavItem(
        icon: Icons.person_outline_rounded,
        label: 'Profile',
        key: ViewKey.settingsProfile,
      ),
      const NavItem(
        icon: Icons.settings_rounded,
        label: 'Config',
        key: ViewKey.settingsConfig,
      ),
    ],
  ),
];

class NavState extends ChangeNotifier {
  ViewKey _view = ViewKey.dashboard;
  bool _sidebarCollapsed = false;
  Map<String, dynamic> _detailData = {};

  String? _selectedBookingId;
  String? _selectedDriverId;
  String? _selectedPatientId;
  String? _selectedTripId;
  String? _selectedVehicleId;
  String? _selectedInvoiceId;

  ViewKey get view => _view;
  bool get sidebarCollapsed => _sidebarCollapsed;
  Map<String, dynamic> get detailData => _detailData;
  String? get selectedBookingId => _selectedBookingId;
  String? get selectedDriverId => _selectedDriverId;
  String? get selectedPatientId => _selectedPatientId;
  String? get selectedTripId => _selectedTripId;
  String? get selectedVehicleId => _selectedVehicleId;
  String? get selectedInvoiceId => _selectedInvoiceId;

  void navigate(ViewKey view) {
    if (_view == view) return;
    _view = view;
    _clearDetailSelection();
    notifyListeners();
  }

  void openDetail(String type, String id, {Map<String, dynamic>? extra}) {
    _detailData = {'type': type, 'id': id, 'extra': extra ?? {}};
    _clearSelectedIds();

    switch (type) {
      case 'booking':
        _selectedBookingId = id;
        break;
      case 'driver':
        _selectedDriverId = id;
        break;
      case 'patient':
        _selectedPatientId = id;
        break;
      case 'trip':
        _selectedTripId = id;
        break;
      case 'vehicle':
        _selectedVehicleId = id;
        break;
      case 'invoice':
        _selectedInvoiceId = id;
        break;
    }

    final viewMap = {
      'invoice': ViewKey.invoiceDetail,
      'booking': ViewKey.bookingDetail,
      'trip': ViewKey.tripDetail,
      'patient': ViewKey.patientProfile,
      'driver': ViewKey.driverProfile,
      'vehicle': ViewKey.vehicleEdit,
    };

    _view = viewMap[type] ?? ViewKey.dashboard;
    notifyListeners();
  }

  void toggleCollapse() {
    _sidebarCollapsed = !_sidebarCollapsed;
    notifyListeners();
  }

  void resetSelection() {
    _clearDetailSelection();
    notifyListeners();
  }

  void _clearDetailSelection() {
    _detailData = {};
    _clearSelectedIds();
  }

  void _clearSelectedIds() {
    _selectedBookingId = null;
    _selectedDriverId = null;
    _selectedPatientId = null;
    _selectedTripId = null;
    _selectedVehicleId = null;
    _selectedInvoiceId = null;
  }
}

bool isActiveOrChild(ViewKey current, ViewKey target) {
  return current == target;
}
