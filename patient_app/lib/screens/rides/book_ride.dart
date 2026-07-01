import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:patient_app/core/services/trip_api_service.dart';
import 'package:patient_app/core/theme/app_theme.dart';

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

  // Mobility & service
  String _mobilityAid = 'NONE';
  String _serviceLevel = 'CURB';
  bool _oxygenRequired = false;
  bool _bariatric = false;
  int _numAttendants = 0;

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
  void dispose() {
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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
          bariatric: _bariatric,
          numAttendants: _numAttendants,
          specialRequirements: _buildSpecialReqs(),
          notes: _notesCtrl.text.trim(),
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
    if (_bariatric) parts.add('Bariatric');
    if (_numAttendants > 0) parts.add('$_numAttendants attendant(s)');
    final notes = _notesCtrl.text.trim();
    if (notes.isNotEmpty) parts.add(notes);
    return parts.join('; ');
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
                          validator: (v) => (v ?? '').isEmpty ? 'Required' : null),
                      const SizedBox(height: 14),
                      _field(ctrl: _destCtrl, label: 'Destination',
                          icon: Icons.location_on_rounded,
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

                    // ── Medical Needs ────────────────────────────────────────
                    _sectionCard(title: 'Medical Requirements', children: [
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
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cTealDeep),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: cTeal, size: 20),
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
