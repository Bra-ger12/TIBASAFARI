import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:patient_app/core/services/trip_api_service.dart';
import 'package:patient_app/core/theme/app_theme.dart';
import 'package:patient_app/models/facility.dart';
import 'package:patient_app/models/fare_breakdown.dart';
import 'package:patient_app/screens/rides/facility_search_screen.dart';
import 'package:patient_app/widgets/fare_estimate_card.dart';

// ── Color aliases ─────────────────────────────────────────────────────────────
const Color cTeal = AppColors.primary;
const Color cTealDark = AppColors.primaryDark;
const Color cTealDeep = AppColors.primaryDeep;
const Color cTealLight = AppColors.primaryExtraLight;
const Color cBorder = AppColors.border;
const Color cMuted = AppColors.textSecondary;
const Color cBg = AppColors.background;
const Color cAmber = AppColors.accent;
const Color cError = AppColors.error;

class BookRideScreen extends StatefulWidget {
  const BookRideScreen({super.key});

  @override
  State<BookRideScreen> createState() => _BookRideScreenState();
}

class _BookRideScreenState extends State<BookRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _scheduledAt;
  bool _isLoading = false;
  bool _resolvingLocation = false;
  // Guards against _onPickupTextEdited wiping out coordinates that
  // _useCurrentLocation just set programmatically on the same controller.
  bool _settingPickupProgrammatically = false;

  // Location picker results (populated via facility search, GPS capture,
  // or a manual address with no coordinates attached).
  double? _pickupLat;
  double? _pickupLng;
  double? _destLat;
  double? _destLng;
  String? _destinationFacilityId;
  FareBreakdown? _lastFareEstimate;

  // Mobility & service
  String _mobilityAid = 'NONE';
  String _serviceLevel = 'CURB';
  bool _oxygenRequired = false;
  bool _medicalEscortRequired = false;
  bool _ivDripRequired = false;
  bool _bariatric = false;
  int _numAttendants = 0;

  // Populated from the patient's profile (set at signup) so we don't ask
  // them to re-enter medical needs they already told us about. If their
  // profile has nothing on file, we nudge them to fill it in here instead.
  bool _profileLoaded = false;
  bool _profileHasMedicalNeeds = false;

  // Recurring
  bool _isRecurring = false;
  String _frequency = 'WEEKLY';
  final List<bool> _daysSelected = List.filled(7, false);

  static const _mobilityOptions = [
    ('NONE', 'None', Icons.directions_walk_rounded),
    ('AMBULATORY', 'Ambulatory', Icons.accessibility_new_rounded),
    ('MANUAL_WC', 'Manual Wheelchair', Icons.wheelchair_pickup_rounded),
    ('POWER_WC', 'Power Wheelchair', Icons.electric_rickshaw_rounded),
    ('STRETCHER', 'Stretcher', Icons.local_hospital_rounded),
  ];

  static const _serviceLevels = [
    ('CURB', 'Curb-to-Curb'),
    ('DOOR', 'Door-to-Door'),
    ('DTD', 'Door-Through-Door'),
  ];

  static const _frequencies = [
    ('DAILY', 'Daily'),
    ('WEEKLY', 'Weekly'),
    ('BIWEEKLY', 'Every 2 Weeks'),
    ('MONTHLY', 'Monthly'),
  ];

  static const _dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  void initState() {
    super.initState();
    _loadMedicalNeedsFromProfile();
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Maps the patient's profile-level mobility need (set once at signup) to
  /// the trip-level mobility aid options offered at booking time.
  static String _mobilityAidFromProfile(String? mobilityNeeds) {
    switch (mobilityNeeds) {
      case 'WHEELCHAIR':
        return 'MANUAL_WC';
      case 'STRETCHER':
        return 'STRETCHER';
      case 'WALKER_CRUTCHES':
        return 'AMBULATORY';
      default:
        return 'NONE';
    }
  }

  /// Pre-fills Mobility Aid / Medical Support from the patient's saved
  /// profile so they aren't asked to re-enter what they already gave us at
  /// signup. If the profile has nothing on file, we leave the fields blank
  /// and show a banner recommending they fill them in for this trip.
  Future<void> _loadMedicalNeedsFromProfile() async {
    try {
      final profile = await TripApiService.instance.getPatientProfile();
      final mobilityNeeds = profile['mobility_needs'] as String?;
      final oxygen = profile['oxygen_required'] as bool? ?? false;
      final escort = profile['medical_escort_required'] as bool? ?? false;
      final ivDrip = profile['iv_drip_required'] as bool? ?? false;
      final hasNeeds = (mobilityNeeds != null && mobilityNeeds != 'NONE') ||
          oxygen ||
          escort ||
          ivDrip;

      if (!mounted) return;
      setState(() {
        _profileLoaded = true;
        _profileHasMedicalNeeds = hasNeeds;
        if (hasNeeds) {
          _mobilityAid = _mobilityAidFromProfile(mobilityNeeds);
          _oxygenRequired = oxygen;
          _medicalEscortRequired = escort;
          _ivDripRequired = ivDrip;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _profileLoaded = true);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: cTeal, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    if (_scheduledAt == null) {
      _snack('Please select a pickup date & time', isError: true);
      return;
    }
    if (_isRecurring && _frequency == 'WEEKLY' && !_daysSelected.contains(true)) {
      _snack('Please select at least one day of the week', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isRecurring) {
        await TripApiService.instance.createRecurringSchedule(
          pickupAddress: _pickupCtrl.text.trim(),
          destinationAddress: _destCtrl.text.trim(),
          pickupTime: '${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')}',
          frequency: _frequency,
          startDate: DateFormat('yyyy-MM-dd').format(_scheduledAt!),
          daysOfWeek: _daysSelected
              .asMap()
              .entries
              .where((e) => e.value)
              .map((e) => e.key)
              .toList(),
          specialRequirements: _buildSpecialReqs(),
        );
        if (mounted) {
          _snack('Recurring schedule created!');
          Navigator.pop(context);
        }
      } else {
        final result = await TripApiService.instance.bookTrip(
          pickupAddress: _pickupCtrl.text.trim(),
          destinationAddress: _destCtrl.text.trim(),
          scheduledAt: _scheduledAt!,
          mobilityAid: _mobilityAid,
          serviceLevel: _serviceLevel,
          oxygenRequired: _oxygenRequired,
          medicalEscortRequired: _medicalEscortRequired,
          ivDripRequired: _ivDripRequired,
          bariatric: _bariatric,
          numAttendants: _numAttendants,
          specialRequirements: _buildSpecialReqs(),
          notes: _notesCtrl.text.trim(),
          pickupLat: _pickupLat,
          pickupLng: _pickupLng,
          destLat: _destLat,
          destLng: _destLng,
          estimatedFare: _lastFareEstimate?.totalFare,
          estimatedFareBreakdown: _lastFareEstimate?.toJson(),
          destinationFacilityId: _destinationFacilityId,
        );
        final data = result['data'] as Map<String, dynamic>? ?? result;
        final tripId = data['id']?.toString();
        if (mounted && tripId != null) {
          _snack('Ride booked successfully!');
          Navigator.pushReplacementNamed(
            context,
            '/track-ride',
            arguments: {
              'rideId': tripId,
              'pickupLocation': _pickupCtrl.text.trim(),
              'destination': _destCtrl.text.trim(),
            },
          );
        }
      }
    } catch (e) {
      if (mounted) _snack('Booking failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _buildSpecialReqs() {
    final parts = <String>[];
    if (_oxygenRequired) parts.add('Oxygen required');
    if (_medicalEscortRequired) parts.add('Medical escort required');
    if (_ivDripRequired) parts.add('IV drip required');
    if (_bariatric) parts.add('Bariatric');
    if (_numAttendants > 0) parts.add('$_numAttendants attendant(s)');
    final notes = _notesCtrl.text.trim();
    if (notes.isNotEmpty) parts.add(notes);
    return parts.join('; ');
  }

  /// Mirrors the backend's service_type_for_trip() (apps/billing/services.py)
  /// so the live fare estimate matches what complete_trip will bill later.
  String _fareServiceType() {
    if (_mobilityAid == 'MANUAL_WC' || _mobilityAid == 'POWER_WC') {
      return 'wheelchair';
    }
    if (_oxygenRequired ||
        _medicalEscortRequired ||
        _ivDripRequired ||
        _bariatric ||
        _mobilityAid == 'STRETCHER') {
      return 'medical_equipment';
    }
    return 'basic';
  }

  /// Searches our own free, OSM-seeded facility database (GET
  /// /facilities/search/) instead of the Google Places "Select Hospital"
  /// picker, which needs billing we don't have enabled.
  Future<void> _pickDestinationFacility() async {
    final facility = await Navigator.push<Facility>(
      context,
      MaterialPageRoute(builder: (_) => const FacilitySearchScreen()),
    );
    if (facility == null || !mounted) return;
    setState(() {
      _destCtrl.text = facility.name;
      _destLat = facility.latitude;
      _destLng = facility.longitude;
      _destinationFacilityId = facility.id;
      _lastFareEstimate = null; // stale until FareEstimateSection re-fetches
    });
  }

  /// Captures the device's raw GPS fix (via `geolocator`) and reverse-geocodes
  /// it on-device (via `geocoding` — no Places/Maps API call) into a readable
  /// pickup address, for patients whose exact pickup point isn't a named
  /// place in Google Places (e.g. a home address or roadside spot).
  Future<void> _useCurrentLocation() async {
    setState(() => _resolvingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission was denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Enable it from '
          'device Settings to use your current location.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      var address =
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [p.street, p.subLocality, p.locality]
              .where((s) => (s ?? '').trim().isNotEmpty)
              .join(', ');
          if (parts.isNotEmpty) address = parts;
        }
      } catch (_) {
        // Reverse geocoding unavailable (offline/unsupported) — fall back
        // to raw coordinates rather than blocking the booking flow.
      }

      if (!mounted) return;
      _settingPickupProgrammatically = true;
      setState(() {
        _pickupCtrl.text = address;
        _pickupLat = position.latitude;
        _pickupLng = position.longitude;
        _lastFareEstimate = null;
      });
      _settingPickupProgrammatically = false;
    } catch (e) {
      if (mounted) {
        _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _resolvingLocation = false);
    }
  }

  /// Manually typing over a GPS-captured address means the previously
  /// captured coordinates no longer match the text, so drop them — the
  /// fare estimate needs real coordinates, not a guess tied to stale ones.
  void _onPickupTextEdited(String _) {
    if (_settingPickupProgrammatically) return;
    if (_pickupLat == null && _pickupLng == null) return;
    setState(() {
      _pickupLat = null;
      _pickupLng = null;
      _lastFareEstimate = null;
    });
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? cError : cTeal,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        title: Text('Book a Ride', style: AppFonts.sora(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: cTeal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: cTeal))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Addresses ──────────────────────────────────────────
                    _sectionCard(title: 'Route', children: [
                      _field(ctrl: _pickupCtrl, label: 'Pickup Location',
                          icon: Icons.trip_origin_rounded,
                          onChanged: _onPickupTextEdited,
                          validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
                          suffix: IconButton(
                            tooltip: 'Use my current location',
                            icon: _resolvingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: cTeal),
                                  )
                                : const Icon(Icons.my_location_rounded,
                                    color: cTeal, size: 18),
                            onPressed:
                                _resolvingLocation ? null : _useCurrentLocation,
                          )),
                      const SizedBox(height: 14),
                      _field(ctrl: _destCtrl, label: 'Destination (Hospital)',
                          icon: Icons.local_hospital_rounded,
                          onTap: _pickDestinationFacility,
                          validator: (v) => (v ?? '').isEmpty ? 'Required' : null),
                    ]),
                    const SizedBox(height: 16),

                    // ── Date & Time ────────────────────────────────────────
                    _sectionCard(title: 'Pickup Date & Time', children: [
                      InkWell(
                        onTap: _pickDateTime,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: cBorder),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: Row(children: [
                            const Icon(Icons.calendar_today_rounded, color: cTeal, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              _scheduledAt != null
                                  ? DateFormat('EEE, MMM d, yyyy  •  h:mm a').format(_scheduledAt!)
                                  : 'Select date and time',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _scheduledAt != null ? cTealDeep : cMuted,
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // ── Medical needs banner ────────────────────────────────
                    if (_profileLoaded && !_profileHasMedicalNeeds) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cAmber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cAmber.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, color: cAmber, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "You didn't set any Mobility Assistance or Medical Support on your "
                                "profile. If you need any for this trip, please select it below.",
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cTealDeep),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else if (_profileHasMedicalNeeds) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cTealLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: cTeal, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Pre-filled from your profile — adjust below if this trip is different.',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cTealDeep),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Mobility Aid ────────────────────────────────────────
                    _sectionCard(title: 'Mobility Aid', children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _mobilityOptions.map((opt) {
                          final selected = _mobilityAid == opt.$1;
                          return ChoiceChip(
                            avatar: Icon(opt.$3, size: 16,
                                color: selected ? Colors.white : cMuted),
                            label: Text(opt.$2),
                            selected: selected,
                            onSelected: (_) => setState(() => _mobilityAid = opt.$1),
                            selectedColor: cTeal,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : cTealDeep,
                            ),
                            side: BorderSide(color: selected ? cTeal : cBorder),
                          );
                        }).toList(),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // ── Service Level ───────────────────────────────────────
                    _sectionCard(title: 'Service Level', children: [
                      RadioGroup<String>(
                        groupValue: _serviceLevel,
                        onChanged: (v) => setState(() => _serviceLevel = v!),
                        child: Column(
                          children: _serviceLevels.map((sl) => RadioListTile<String>(
                            value: sl.$1,
                            title: Text(sl.$2,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cTealDeep)),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          )).toList(),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // ── Medical Support ─────────────────────────────────────
                    _sectionCard(title: 'Medical Support', children: [
                      SwitchListTile(
                        value: _oxygenRequired,
                        onChanged: (v) => setState(() => _oxygenRequired = v),
                        title: const Text('Oxygen Support', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cTealDeep)),
                        secondary: const Icon(Icons.monitor_heart_rounded, color: cTeal, size: 20),
                        activeThumbColor: Colors.white,
                        activeTrackColor: cTeal,
                        contentPadding: EdgeInsets.zero, dense: true,
                      ),
                      SwitchListTile(
                        value: _medicalEscortRequired,
                        onChanged: (v) => setState(() => _medicalEscortRequired = v),
                        title: const Text('Medical Escort', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cTealDeep)),
                        secondary: const Icon(Icons.medical_services_rounded, color: cTeal, size: 20),
                        activeThumbColor: Colors.white,
                        activeTrackColor: cTeal,
                        contentPadding: EdgeInsets.zero, dense: true,
                      ),
                      SwitchListTile(
                        value: _ivDripRequired,
                        onChanged: (v) => setState(() => _ivDripRequired = v),
                        title: const Text('IV Drip Required', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cTealDeep)),
                        secondary: const Icon(Icons.water_drop_rounded, color: cTeal, size: 20),
                        activeThumbColor: Colors.white,
                        activeTrackColor: cTeal,
                        contentPadding: EdgeInsets.zero, dense: true,
                      ),
                      SwitchListTile(
                        value: _bariatric,
                        onChanged: (v) => setState(() => _bariatric = v),
                        title: const Text('Bariatric Transport', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cTealDeep)),
                        secondary: const Icon(Icons.accessible_rounded, color: cTeal, size: 20),
                        activeThumbColor: Colors.white,
                        activeTrackColor: cTeal,
                        contentPadding: EdgeInsets.zero, dense: true,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Attendants', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cTealDeep)),
                          Row(children: [
                            _counterBtn(Icons.remove_rounded,
                                () => setState(() => _numAttendants = (_numAttendants - 1).clamp(0, 5))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('$_numAttendants',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cTealDeep)),
                            ),
                            _counterBtn(Icons.add_rounded,
                                () => setState(() => _numAttendants = (_numAttendants + 1).clamp(0, 5))),
                          ]),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // ── Fare Estimate ─────────────────────────────────────────
                    if (!_isRecurring &&
                        _pickupLat != null &&
                        _pickupLng != null &&
                        _destLat != null &&
                        _destLng != null) ...[
                      FareEstimateSection(
                        pickupLat: _pickupLat!,
                        pickupLng: _pickupLng!,
                        destLat: _destLat!,
                        destLng: _destLng!,
                        serviceType: _fareServiceType(),
                        scheduledAt: _scheduledAt,
                        onEstimate: (b) => _lastFareEstimate = b,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Recurring ─────────────────────────────────────────────
                    _sectionCard(title: 'Recurring Schedule', children: [
                      SwitchListTile(
                        value: _isRecurring,
                        onChanged: (v) => setState(() => _isRecurring = v),
                        title: const Text('Set as recurring ride',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cTealDeep)),
                        activeThumbColor: Colors.white,
                        activeTrackColor: cTeal,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      if (_isRecurring) ...[
                        const SizedBox(height: 12),
                        const Text('Frequency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cMuted)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _frequencies.map((f) {
                            final sel = _frequency == f.$1;
                            return ChoiceChip(
                              label: Text(f.$2),
                              selected: sel,
                              onSelected: (_) => setState(() => _frequency = f.$1),
                              selectedColor: cTeal,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : cTealDeep),
                              side: BorderSide(color: sel ? cTeal : cBorder),
                            );
                          }).toList(),
                        ),
                        if (_frequency == 'WEEKLY') ...[
                          const SizedBox(height: 12),
                          const Text('Days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cMuted)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(7, (i) {
                              final sel = _daysSelected[i];
                              return GestureDetector(
                                onTap: () => setState(() => _daysSelected[i] = !sel),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    color: sel ? cTeal : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: sel ? cTeal : cBorder, width: 1.5),
                                  ),
                                  child: Center(
                                    child: Text(_dayLabels[i],
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                            color: sel ? Colors.white : cMuted)),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ],
                    ]),
                    const SizedBox(height: 16),

                    // ── Notes ───────────────────────────────────────────────
                    _sectionCard(title: 'Additional Notes', children: [
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Any special instructions, conditions, or notes…',
                          hintStyle: const TextStyle(color: cMuted, fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cTeal, width: 2)),
                          filled: true, fillColor: Colors.white,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 28),

                    // ── Submit ──────────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cTeal, foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          _isRecurring ? 'CREATE RECURRING SCHEDULE' : 'BOOK RIDE',
                          style: AppFonts.sora(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppFonts.sora(fontSize: 14, fontWeight: FontWeight.w800, color: cTealDeep)),
            const SizedBox(height: 14),
            ...children,
          ]),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    void Function(String)? onChanged,
    Widget? suffix,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      readOnly: onTap != null,
      onTap: onTap,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cTealDeep),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: cTeal, size: 20),
        suffixIcon: suffix ??
            (onTap != null
                ? const Icon(Icons.search, color: cMuted, size: 18)
                : null),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cTeal, width: 2)),
        filled: true, fillColor: Colors.white,
      ),
      validator: validator,
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) => Material(
        color: cTealLight,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 18, color: cTeal)),
        ),
      );
}
