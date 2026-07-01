import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'status_badge.dart';
import '../services/format.dart';

class AssignDriverDialog extends StatefulWidget {
  final String bookingReference;
  final List<Driver> drivers;
  final bool loading;
  final void Function(String driverId) onAssign;
  const AssignDriverDialog({
    super.key,
    required this.bookingReference,
    required this.drivers,
    required this.loading,
    required this.onAssign,
  });

  @override
  State<AssignDriverDialog> createState() => _AssignDriverDialogState();
}

class _AssignDriverDialogState extends State<AssignDriverDialog> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final available =
        widget.drivers.where((d) => d.status == 'online').toList();
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),  // ✅ FIXED
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_add_alt_1,
                        size: 18, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 10),
                  const Text('Assign Driver',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Select an available driver to assign to booking ${widget.bookingReference}. Only online drivers are shown.',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
            const Divider(height: 20),
            available.isEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 40, horizontal: 20),
                    alignment: Alignment.center,
                    child: Column(
                      children: const [
                        Icon(Icons.directions_car,
                            size: 32, color: AppTheme.textMuted),
                        SizedBox(height: 8),
                        Text('No drivers available',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text(
                            'All drivers are currently offline or on a trip.',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  )
                : RadioGroup<String>(
                    groupValue: _selected,
                    onChanged: (v) => setState(() => _selected = v),
                    child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: available.length,
                      itemBuilder: (context, i) {
                        final d = available[i];
                        final sel = _selected == d.id;
                        final meta = driverStatus(d.status);
                        return RadioListTile<String>(
                          value: d.id,
                          activeColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                                color: sel
                                    ? AppTheme.primary.withValues(alpha: 0.4)  // ✅ FIXED
                                    : Colors.transparent),
                          ),
                          tileColor: sel
                              ? AppTheme.primary.withValues(alpha: 0.05)  // ✅ FIXED
                              : null,
                          title: Row(
                            children: [
                              AvatarCircle(
                                  name: d.name,
                                  color: avatarColor(d.avatarColor),
                                  size: 32),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(d.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.star,
                                            size: 12,
                                            color: Colors.amber[600]),
                                        const SizedBox(width: 2),
                                        Text(d.rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textMuted)),
                                        const SizedBox(width: 6),
                                        Text('· ${d.tripsCount} trips',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textMuted)),
                                        if (d.vehicle != null) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                              '· ${d.vehicle!.plate} · ${vehicleTypeLabel(d.vehicle!.type)}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textMuted)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(tone: meta.tone, label: meta.label, dot: true),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: (_selected == null || widget.loading)
                        ? null
                        : () => widget.onAssign(_selected!),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.4),  // ✅ FIXED
                    ),
                    child: widget.loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Assign Driver'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}