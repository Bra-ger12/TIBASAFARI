import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class KPICard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final int? trend;
  final String? trendLabel;
  final Color accent;

  const KPICard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.trend,
    this.trendLabel,
    this.accent = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    final positive = (trend ?? 0) >= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textMuted)),
                      const SizedBox(height: 4),
                      Text(value,
                          style: AppFonts.sora(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
              ],
            ),
            if (trend != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: positive
                          ? AppTheme.primary.withValues(alpha: 0.1)
                          : const Color(0xFFF43F5E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          positive
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 12,
                          color: positive
                              ? AppTheme.primary
                              : const Color(0xFFF43F5E),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${trend!.abs()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: positive
                                ? AppTheme.primary
                                : const Color(0xFFF43F5E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(trendLabel ?? 'vs yesterday',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
