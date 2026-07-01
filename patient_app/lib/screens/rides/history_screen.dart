import 'package:flutter/material.dart';
import 'package:patient_app/core/services/trip_api_service.dart';
import 'package:patient_app/core/theme/app_theme.dart';

const Color cTeal = AppColors.primary;
const Color cTealDark = AppColors.primaryDark;
const Color cTealDeep = AppColors.primaryDeep;
const Color cTealMid = AppColors.primaryLight;
const Color cTealLight = AppColors.primaryExtraLight;
const Color cBorder = AppColors.border;
const Color cDivider = AppColors.divider;
const Color cMuted = AppColors.textSecondary;
const Color cMutedLight = AppColors.textMuted;
const Color cError = AppColors.error;
const Color cAmber = AppColors.accent;
const Color cBg = AppColors.background;
const Color cBlue = AppColors.secondary;
const Color cOrange = AppColors.orange;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  String _filter = 'all';
  bool _isLoading = true;

  late final AnimationController _animController;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  final List<Map<String, dynamic>> _trips = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnims = List.generate(4, (i) {
      final s = (i * 0.1).clamp(0.0, 0.6);
      final e = (s + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(s, e, curve: Curves.easeOut),
        ),
      );
    });

    _slideAnims = List.generate(4, (i) {
      final s = (i * 0.1).clamp(0.0, 0.6);
      final e = (s + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(s, e, curve: Curves.easeOut),
        ),
      );
    });

    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      final raw = await TripApiService.instance.getMyTrips();
      final mapped = raw
          .map((t) => TripApiService.mapTripForDisplay(t as Map<String, dynamic>))
          .where((t) => t['status'] == 'completed' || t['status'] == 'cancelled')
          .toList();
      if (mounted) {
        setState(() {
          _trips
            ..clear()
            ..addAll(mapped);
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load trips: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: cError,
        ));
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _anim(int i, Widget child) => FadeTransition(
        opacity: _fadeAnims[i],
        child: SlideTransition(position: _slideAnims[i], child: child),
      );

  List<Map<String, dynamic>> get _filteredTrips {
    if (_filter == 'all') return _trips;
    return _trips.where((t) => t['status'] == _filter).toList();
  }

  int _countForFilter(String filter) {
    if (filter == 'all') return _trips.length;
    return _trips.where((t) => t['status'] == filter).length;
  }

  @override
  Widget build(BuildContext context) {
    final trips = _filteredTrips;

    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: cDivider)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0F0F6E56),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: cTealLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: cTealDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Trip History',
                    style: AppFonts.sora(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: cTealDeep,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: _anim(
                  0,
                  Row(
                    children: ['all', 'completed', 'cancelled'].map((f) {
                      final label = f == 'all'
                          ? 'All'
                          : f == 'completed'
                              ? 'Completed'
                              : 'Cancelled';
                      final count = _countForFilter(f);
                      final isActive = _filter == f;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _filter = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive ? cTeal : Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isActive ? cTeal : cBorder,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isActive ? Colors.white : cMuted,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0x40FFFFFF)
                                        : cTealLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isActive
                                          ? Colors.white
                                          : cTealDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            if (!_isLoading) const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: cTeal),
                    )
                  : trips.isEmpty
                      ? _anim(
                          1,
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inbox_rounded,
                                  size: 56,
                                  color: cMutedLight.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'No trips found',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: cMutedLight,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _filter == 'all'
                                      ? 'Your completed and cancelled\ntrips will appear here'
                                      : 'No $_filter trips to show',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cMutedLight.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: trips.length,
                          itemBuilder: (context, index) {
                            final trip = trips[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _HistoryTripCard(
                                trip: trip,
                                onTap: () => _showTripDetail(trip),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTripDetail(Map<String, dynamic> trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TripDetailSheet(trip: trip),
    );
  }
}

class _HistoryTripCard extends StatefulWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onTap;

  const _HistoryTripCard({required this.trip, required this.onTap});

  @override
  State<_HistoryTripCard> createState() => _HistoryTripCardState();
}

class _HistoryTripCardState extends State<_HistoryTripCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final isCompleted = trip['status'] == 'completed';
    final statusColor = isCompleted ? cTeal : cError;
    final statusBg =
        isCompleted ? cTealLight : const Color(0xFFFFEDED);
    final statusLabel = isCompleted ? 'Completed' : 'Cancelled';

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cBorder, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F6E56),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 22,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip['destination'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: cTealDeep,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          trip['pickup'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: cMutedLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: cDivider, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DetailChip(
                    icon: Icons.calendar_today_rounded,
                    label: trip['date'] ?? '',
                    color: cBlue,
                  ),
                  _DetailChip(
                    icon: Icons.access_time_rounded,
                    label: trip['time'] ?? '',
                    color: cAmber,
                  ),
                  if (trip['fare'] != null)
                    _DetailChip(
                      icon: Icons.payments_rounded,
                      label: trip['fare'] ?? '',
                      color: cTeal,
                    ),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: cMutedLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: cMuted,
          ),
        ),
      ],
    );
  }
}

class _TripDetailSheet extends StatefulWidget {
  final Map<String, dynamic> trip;
  const _TripDetailSheet({required this.trip});

  @override
  State<_TripDetailSheet> createState() => _TripDetailSheetState();
}

class _TripDetailSheetState extends State<_TripDetailSheet> {
  bool _isRated = false;
  int _ratingScore = 0;
  bool _submittingRating = false;

  @override
  void initState() {
    super.initState();
    _isRated = widget.trip['is_rated'] == true;
    _ratingScore = (widget.trip['rating_score'] as num?)?.toInt() ?? 0;
  }

  Future<void> _showRatingDialog() async {
    int selected = 0;
    final comment = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Rate This Trip', style: TextStyle(fontWeight: FontWeight.w800, color: cTealDeep)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How was your experience?', style: TextStyle(color: cMuted)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setDlg(() => selected = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        star <= selected ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 36,
                        color: star <= selected ? cAmber : cMutedLight,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: comment,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Leave a comment (optional)',
                  hintStyle: const TextStyle(fontSize: 13, color: cMutedLight),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: cMuted)),
            ),
            ElevatedButton(
              onPressed: selected == 0 ? null : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: cTeal, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selected == 0) return;

    setState(() => _submittingRating = true);
    try {
      final tripId = widget.trip['id'] as String;
      await TripApiService.instance.rateTrip(tripId, selected, comment.text.trim());
      if (mounted) {
        setState(() { _isRated = true; _ratingScore = selected; _submittingRating = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Thank you for your rating!'),
          backgroundColor: cTeal,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submittingRating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: cError,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final isCompleted = trip['status'] == 'completed';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? cTealLight
                      : const Color(0xFFFFEDED),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 28,
                  color: isCompleted ? cTeal : cError,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip['destination'] ?? '',
                      style: AppFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: cTealDeep,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      trip['date'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: cMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _SheetRow(
                  icon: Icons.radio_button_checked_rounded,
                  color: cTeal,
                  label: 'Pickup',
                  value: trip['pickup'] ?? '',
                ),
                const SizedBox(height: 12),
                Container(
                  width: 1.5,
                  height: 16,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: cBorder,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 12),
                _SheetRow(
                  icon: Icons.location_on_rounded,
                  color: cError,
                  label: 'Destination',
                  value: trip['destination'] ?? '',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _SheetRow(
                  icon: Icons.directions_car_rounded,
                  color: cTeal,
                  label: 'Vehicle',
                  value: trip['vehicle'] ?? '',
                ),
                const SizedBox(height: 10),
                _SheetRow(
                  icon: Icons.access_time_rounded,
                  color: cAmber,
                  label: 'Time',
                  value: trip['time'] ?? '',
                ),
                if (trip['duration'] != null) ...[
                  const SizedBox(height: 10),
                  _SheetRow(
                    icon: Icons.timeline_rounded,
                    color: cBlue,
                    label: 'Duration',
                    value: trip['duration'] ?? '',
                  ),
                ],
                if (trip['fare'] != null) ...[
                  const SizedBox(height: 10),
                  _SheetRow(
                    icon: Icons.payments_rounded,
                    color: cTeal,
                    label: 'Fare',
                    value: trip['fare'] ?? '',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Rating section (completed trips only)
          if (isCompleted) ...[
            if (_isRated)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: cTealLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ...List.generate(5, (i) => Icon(
                    i < _ratingScore ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 22, color: cAmber,
                  )),
                  const SizedBox(width: 8),
                  Text('Your rating: $_ratingScore/5',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cTealDeep)),
                ]),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _submittingRating ? null : _showRatingDialog,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: cTeal, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    foregroundColor: cTeal,
                  ),
                  icon: _submittingRating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cTeal))
                      : const Icon(Icons.star_rounded, size: 18),
                  label: Text(_submittingRating ? 'Submitting…' : 'Rate This Trip',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cTeal, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Close', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: cBorder, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  foregroundColor: cMuted,
                ),
                child: const Text('Close', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _SheetRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cMutedLight,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: cTealDeep,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}