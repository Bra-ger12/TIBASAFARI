import 'package:flutter/material.dart';
import 'package:patient_app/core/theme/app_theme.dart';

const Color cTeal = AppColors.primary;
const Color cTealDark = AppColors.primaryDark;
const Color cDivider = AppColors.divider;
const Color cMutedLight = AppColors.textMuted;

class BottomNavBar extends StatelessWidget {
  final String activeTab;
  final Function(String) onTab;

  const BottomNavBar({
    super.key,
    required this.activeTab,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const _TabItem(
        id: 'home',
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      const _TabItem(
        id: 'book',
        label: 'Book',
        icon: Icons.add_circle_outline_rounded,
        activeIcon: Icons.add_circle_rounded,
        isSpecial: true,
      ),
      const _TabItem(
        id: 'history',
        label: 'History',
        icon: Icons.history_outlined,
        activeIcon: Icons.history_rounded,
      ),
      const _TabItem(
        id: 'profile',
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: cDivider),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: tabs.map((tab) {
              final isActive = activeTab == tab.id;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTab(tab.id),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tab.isSpecial)
                        Container(
                          width: 48,
                          height: 48,
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [cTeal, cTealDark],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x590E7C66),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 26,
                            color: Colors.white,
                          ),
                        )
                      else
                        Icon(
                          isActive ? tab.activeIcon : tab.icon,
                          size: 24,
                          color: isActive ? cTeal : cMutedLight,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: AppFonts.sora(
                          fontSize: 10.5,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w600,
                          color: isActive ? cTeal : cMutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isSpecial;

  const _TabItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.isSpecial = false,
  });
}
