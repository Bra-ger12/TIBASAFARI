import 'package:flutter/material.dart';
import 'package:driver_app/core/models/driver_session.dart'; 
import '../../core/theme/colors.dart';
import '../../services/driver_service.dart';

class ActiveTripScreen extends StatefulWidget {
  final DriverSession session;

  const ActiveTripScreen({super.key, required this.session});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> with SingleTickerProviderStateMixin {
  late DriverSession _session;
  DriverAssignedTrip? _trip;
  bool _isUpdating = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    // FIXED: Removed unnecessary cast
    _trip = _session.activeTrip;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _updateTripStatus(TripAssignmentStatus newStatus, String actionName) async {
    if (_trip == null) return;

    setState(() => _isUpdating = true);

    try {
      // Actual backend call to update trip status
      final updatedTrip = await DriverService.instance.updateTripStatus(
        driverUid: _session.driverId,
        tripId: _trip!.id,
        status: newStatus,
      );

      if (!mounted) return;

      setState(() {
        _trip = updatedTrip;
        
        if (newStatus == TripAssignmentStatus.completed) {
          // FIXED: Removed unnecessary cast
          final List<DriverAssignedTrip> updatedTrips = _session.assignedTrips
              .map((t) => t)
              .map((trip) => trip.id == updatedTrip.id ? updatedTrip : trip)
              .toList();
          
          _session = _session.copyWith(
            tripsToday: _session.tripsToday + 1,
            assignedTrips: updatedTrips,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trip $actionName successfully!', style: const TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: newStatus == TripAssignmentStatus.completed ? Colors.green : cTeal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      if (newStatus == TripAssignmentStatus.completed) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.pop(context, _session); // Return updated session to previous screen
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update trip: $e', style: const TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: cError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _callPatient() {
    if (_trip == null) return;
    
    // Actual implementation would use url_launcher to call _trip!.patientPhone
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${_trip!.patientName}...'),
        backgroundColor: cTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _getActionButtonText() {
    if (_trip == null) return '';
    switch (_trip!.status) {
      case TripAssignmentStatus.assigned:
        return 'Start Trip / Head to Pickup';
      case TripAssignmentStatus.accepted:
        return "I've Arrived at Pickup";
      case TripAssignmentStatus.inProgress:
        return "I've Arrived";
      case TripAssignmentStatus.arrived:
        return 'Complete Trip';
      case TripAssignmentStatus.completed:
        return 'Trip Completed';
      case TripAssignmentStatus.cancelled:
        return 'Trip Cancelled';
    }
  }

  VoidCallback? _getActionButtonCallback() {
    if (_trip == null) return null;
    switch (_trip!.status) {
      case TripAssignmentStatus.assigned:
        return () => _updateTripStatus(TripAssignmentStatus.accepted, 'started');
      case TripAssignmentStatus.accepted:
        return () => _updateTripStatus(TripAssignmentStatus.inProgress, 'started');
      case TripAssignmentStatus.inProgress:
        return () => _updateTripStatus(TripAssignmentStatus.arrived, 'arrived');
      case TripAssignmentStatus.arrived:
        return () => _updateTripStatus(TripAssignmentStatus.completed, 'completed');
      case TripAssignmentStatus.completed:
      case TripAssignmentStatus.cancelled:
        return null;
    }
  }

  int _getCurrentStep() {
    if (_trip == null) return -1;
    switch (_trip!.status) {
      case TripAssignmentStatus.assigned: return 0;
      case TripAssignmentStatus.accepted: return 1;
      case TripAssignmentStatus.inProgress: return 2;
      case TripAssignmentStatus.arrived: return 2;
      case TripAssignmentStatus.completed: return 3;
      case TripAssignmentStatus.cancelled: return -1;
    }
  }

  Color _getStatusColor(TripAssignmentStatus status) {
    switch (status) {
      case TripAssignmentStatus.assigned: return Colors.blue;
      case TripAssignmentStatus.accepted: return cTeal;
      case TripAssignmentStatus.inProgress: return cAmber;
      case TripAssignmentStatus.arrived: return cAmber;
      case TripAssignmentStatus.completed: return Colors.green;
      case TripAssignmentStatus.cancelled: return cError;
    }
  }

  String _getStatusDisplayName(TripAssignmentStatus status) {
    switch (status) {
      case TripAssignmentStatus.assigned: return 'Assigned';
      case TripAssignmentStatus.accepted: return 'Accepted';
      case TripAssignmentStatus.inProgress: return 'In Progress';
      case TripAssignmentStatus.arrived: return 'Arrived';
      case TripAssignmentStatus.completed: return 'Completed';
      case TripAssignmentStatus.cancelled: return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_trip == null) {
      return _buildEmptyState();
    }

    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPatientInfo(),
                    const SizedBox(height: 20),
                    _buildLocationTimeline(),
                    const SizedBox(height: 20),
                    _buildMapPreview(),
                    const SizedBox(height: 24),
                    _buildStatusStepper(),
                    const SizedBox(height: 24),
                    _buildTripDetails(),
                    const SizedBox(height: 16),
                    if (_trip!.specialRequirements.isNotEmpty) ...[
                      _buildRequirementsSection(),
                      const SizedBox(height: 24),
                    ],
                    if (_getActionButtonCallback() != null) _buildActionButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_rounded, color: cTealDeep, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('Active Trip', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cTealDeep)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(_trip!.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getStatusDisplayName(_trip!.status).toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _getStatusColor(_trip!.status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: cTealLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_car_rounded, size: 60, color: cTeal),
                ),
                const SizedBox(height: 24),
                const Text('No Active Trip', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cTealDeep)),
                const SizedBox(height: 8),
                const Text(
                  "You don't have any active trip assigned right now.",
                  style: TextStyle(fontSize: 14, color: cMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  child: const Text('Go Back', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0A0F6E56), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [cTeal, cTealDark]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.person_rounded, size: 28, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _trip!.patientName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: cTealDeep),
                ),
                const SizedBox(height: 4),
                Text(
                  _trip!.appointmentType,
                  style: TextStyle(
                    fontSize: 13,
                    color: _trip!.appointmentType.toLowerCase().contains('wheelchair') ? Colors.blue : cTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _callPatient,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cTealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_rounded, size: 22, color: cTeal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTimeline() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0A0F6E56), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Graphics
          Column(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.blue.withValues(alpha: 0.2), width: 4)),
              ),
              Container(width: 2, height: 40, color: cDivider),
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: cTeal, shape: BoxShape.circle, border: Border.all(color: cTeal.withValues(alpha: 0.2), width: 4)),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PICKUP LOCATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: cMutedLight, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(_trip!.pickupAddress, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cTealDeep)),
                const SizedBox(height: 20),
                const Text('DESTINATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: cMutedLight, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(_trip!.destination, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cTealDeep)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [cTealLight, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: cBorder),
        boxShadow: const [BoxShadow(color: Color(0x0A0F6E56), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Stack(
        children: [
          // Abstract map lines
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: CustomPaint(painter: _MapLinePainter()),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.2).animate(
                    CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cTeal,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: cTeal.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)],
                    ),
                    child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Live Navigation Active', style: TextStyle(fontSize: 13, color: cTealDeep, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStepper() {
    final currentStep = _getCurrentStep();
    if (currentStep == -1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0A0F6E56), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trip Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cTealDeep)),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStepperStep(0, 'Assigned', Icons.assignment_rounded, currentStep),
              Expanded(child: _buildStepperLine(0, currentStep)),
              _buildStepperStep(1, 'Accepted', Icons.directions_car_rounded, currentStep),
              Expanded(child: _buildStepperLine(1, currentStep)),
              _buildStepperStep(2, 'En Route', Icons.location_on_rounded, currentStep),
              Expanded(child: _buildStepperLine(2, currentStep)),
              _buildStepperStep(3, 'Done', Icons.check_circle_rounded, currentStep),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepperStep(int step, String label, IconData icon, int currentStep) {
    final isActive = step <= currentStep;
    final isCurrent = step == currentStep;
    return Column(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isActive ? cTeal : cBg,
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? cTeal : cDivider, width: 2),
            boxShadow: isCurrent ? [BoxShadow(color: cTeal.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)] : [],
          ),
          child: Icon(icon, size: 18, color: isActive ? Colors.white : cMutedLight),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? cTealDeep : cMutedLight,
          ),
        ),
      ],
    );
  }

  Widget _buildStepperLine(int step, int currentStep) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: step < currentStep ? cTeal : cDivider,
    );
  }

  Widget _buildTripDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0A0F6E56), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trip Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cTealDeep)),
          const SizedBox(height: 16),
          _buildDetailRow('Trip ID', _trip!.id),
          const Divider(color: cDivider, height: 24),
          _buildDetailRow('Pickup Time', _trip!.pickupTime),
          const Divider(color: cDivider, height: 24),
          _buildDetailRow('Vehicle', '${_session.vehicleType.displayName} - ${_session.vehiclePlate}'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: cMuted, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cTealDeep)),
      ],
    );
  }

  Widget _buildRequirementsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cAmber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cAmber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: cAmber),
              const SizedBox(width: 8),
              const Text('Special Requirements', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cAmber)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _trip!.specialRequirements.map((req) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cAmber.withValues(alpha: 0.4)),
              ),
              child: Text(req, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cTealDeep)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final isCompleted = _trip!.status == TripAssignmentStatus.completed;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUpdating ? null : _getActionButtonCallback(),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: isCompleted ? Colors.green : cTeal,
          disabledBackgroundColor: cTeal.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: cTeal.withValues(alpha: 0.3),
        ),
        child: _isUpdating
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isCompleted ? Icons.check_circle_rounded : Icons.arrow_forward_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(_getActionButtonText(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
      ),
    );
  }
}

class _MapLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cTeal
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.2, size.width * 0.5, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.75, size.height, size.width, size.height * 0.3);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}