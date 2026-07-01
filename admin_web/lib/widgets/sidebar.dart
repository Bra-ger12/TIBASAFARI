import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'nav.dart'; // Import NavState and ViewKey from here

class AppSidebar extends StatelessWidget {
  final NavState nav;
  final bool isMobile;
  const AppSidebar({super.key, required this.nav, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: nav,
      builder: (context, _) {
        final collapsed = nav.sidebarCollapsed && !isMobile;
        final width = collapsed ? 64.0 : 256.0;
        return Container(
          width: width,
          color: AppTheme.sidebarBg,
          child: Column(
            children: [
              // Brand
              Container(
                height: 56,
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 0 : 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: Row(
                  mainAxisAlignment: collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/tiba-safari-logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.medical_services,
                              color: Colors.white,
                              size: 18,
                            ),
                      ),
                    ),
                    if (!collapsed) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Tiba Safari',
                              style: AppFonts.sora(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Operations Center',
                              style: AppFonts.manrope(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Nav list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final section in navSections) ...[
                      if (section.items.length > 1 && !collapsed)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 12,
                            top: 10,
                            bottom: 4,
                          ),
                          child: Text(
                            section.title.toUpperCase(),
                            style: AppFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.4),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      for (final item in section.items)
                        _NavItem(
                          item: item,
                          active: isActiveOrChild(nav.view, item.key),
                          collapsed: collapsed,
                          onTap: () {
                            nav.resetSelection();
                            nav.navigate(item.key);
                          },
                        ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              // Collapse toggle (desktop only)
              if (!isMobile)
                Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  child: TextButton.icon(
                    onPressed: nav.toggleCollapse,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: collapsed ? 0 : 16,
                        vertical: 12,
                      ),
                      foregroundColor: Colors.white.withValues(alpha: 0.55),
                    ),
                    icon: Icon(
                      collapsed ? Icons.chevron_right : Icons.chevron_left,
                      size: 18,
                    ),
                    label: collapsed
                        ? const SizedBox.shrink()
                        : const Text(
                            'Collapse',
                            style: TextStyle(fontSize: 13),
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavItem item;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;
  const _NavItem({
    required this.item,
    required this.active,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: collapsed ? item.label : '',
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 10,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: active ? AppTheme.primary.withValues(alpha: 0.22) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: active ? Colors.white : Colors.white.withValues(alpha: 0.55),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Text(
                    item.label,
                    style: AppFonts.manrope(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Colors.white : Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
