import 'package:flutter/material.dart';
import 'package:patient_app/core/services/auth_service.dart';
import 'package:patient_app/models/auth_session.dart';
import 'package:patient_app/core/theme/app_theme.dart';
import 'package:patient_app/screens/profile/profile_sub_screens.dart';

const Color cTeal = AppColors.primary;
const Color cTealDark = AppColors.primaryDark;
const Color cTealDeep = AppColors.primaryDeep;
const Color cTealLight = AppColors.primaryExtraLight;
const Color cBorder = AppColors.border;
const Color cDivider = AppColors.divider;
const Color cMuted = AppColors.textSecondary;
const Color cMutedLight = AppColors.textMuted;
const Color cError = AppColors.error;
const Color cAmber = AppColors.accent;
const Color cBg = AppColors.background;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  bool isLoading = true;
  AuthSession? session;
  int notificationCount = 0;

  late final AnimationController _animController;
  late final List<Animation<double>> _fadeAnims;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnims = List.generate(3, (i) {
      final s = (i * 0.15).clamp(0.0, 0.5);
      final e = (s + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animController, curve: Interval(s, e, curve: Curves.easeOut)));
    });
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    session = await AuthSession.load();
    notificationCount = session?.unreadNotifications ?? 0;
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => isLoading = false);
      _animController.forward();
    }
  }

  Future<void> _logout() async {
    final authService = AuthService();
    await authService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w800, color: cTealDeep)),
        content: const Text('Are you sure you want to log out of Tiba Safari?', style: TextStyle(color: cMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: cMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _logout(); },
            style: ElevatedButton.styleFrom(backgroundColor: cError, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _anim(int i, Widget child) => FadeTransition(opacity: _fadeAnims[i], child: child);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: cTeal))
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      child: Column(
                        children: [
                          _anim(0, _buildProfileHeader()),
                          const SizedBox(height: 24),
                          _anim(1, _buildStatsRow()),
                          const SizedBox(height: 28),
                          _anim(2, _buildMenuSections()),
                          const SizedBox(height: 24),
                          if (session?.isLoggedIn == true) _buildLogoutButton(),
                          const SizedBox(height: 20),
                          Text('Version 1.0.0', style: TextStyle(color: cMutedLight.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w500)),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: cDivider)), boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4))]),
      child: Row(
        children: [
          InkWell(onTap: () => Navigator.pop(context), borderRadius: BorderRadius.circular(12), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: cTealLight, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_back_rounded, size: 22, color: cTealDark))),
          const SizedBox(width: 14),
          Text('My Profile', style: AppFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: cTealDeep)),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: cBorder), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]),
      child: Row(
        children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [cTeal, cTealDark]), borderRadius: BorderRadius.all(Radius.circular(20)), boxShadow: [BoxShadow(color: Color(0x331D9E75), blurRadius: 12, offset: Offset(0, 4))]),
            child: Center(child: Text(session?.displayName.isNotEmpty == true ? session!.displayName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white))),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session?.displayName ?? '', style: AppFonts.sora(fontSize: 20, fontWeight: FontWeight.w800, color: cTealDeep)),
                const SizedBox(height: 4),
                Row(children: [const Icon(Icons.email_outlined, size: 14, color: cMutedLight), const SizedBox(width: 6), Expanded(child: Text(session?.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: cMuted, fontWeight: FontWeight.w500)))]),
                if (session?.phone != null && session!.phone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [const Icon(Icons.phone_outlined, size: 14, color: cMutedLight), const SizedBox(width: 6), Text(session!.phone, style: const TextStyle(fontSize: 13, color: cMuted, fontWeight: FontWeight.w500))]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: cBorder), boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 4))]),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: _statBlock(label: 'Total Trips', value: '${session?.totalTrips ?? 0}', icon: Icons.directions_car_rounded, color: cTeal)),
            const VerticalDivider(width: 1, thickness: 1, color: cDivider, indent: 16, endIndent: 16),
            Expanded(child: _statBlock(label: 'This Month', value: '${session?.tripsThisMonth ?? 0}', icon: Icons.calendar_today_rounded, color: const Color(0xFF3B82F6))),
            const VerticalDivider(width: 1, thickness: 1, color: cDivider, indent: 16, endIndent: 16),
            Expanded(child: _statBlock(label: 'Time Saved', value: session?.timeSaved ?? '0 hr', icon: Icons.access_time_rounded, color: cAmber)),
          ],
        ),
      ),
    );
  }

  Widget _statBlock({required String label, required String value, required IconData icon, required Color color}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: const BorderRadius.all(Radius.circular(12))), child: Icon(icon, size: 20, color: color)),
      const SizedBox(height: 10), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cTealDeep, height: 1)),
      const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 11.5, color: cMutedLight, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    ]));
  }

  Widget _buildMenuSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _menuGroup(items: [
          _menuItem(icon: Icons.person_outline_rounded, title: 'Personal Information', onTap: () => _navigate(const PersonalInfoScreen())),
          _menuItem(icon: Icons.medical_information_outlined, title: 'Medical Profile', badge: 'Setup Required', badgeColor: cAmber, onTap: () => _navigate(const MedicalProfileScreen())),
          _menuItem(icon: Icons.contact_phone_outlined, title: 'Emergency Contacts', onTap: () => _navigate(const EmergencyContactsScreen())),
          _menuItem(icon: Icons.payment_outlined, title: 'Payment Methods', badge: 'M-Pesa', badgeColor: cTeal, onTap: () => _navigate(const PaymentMethodsScreen())),
        ]),
        const SizedBox(height: 16),
        _menuGroup(items: [
          _menuItem(icon: Icons.notifications_outlined, title: 'Notifications', badge: notificationCount > 0 ? '$notificationCount new' : null, badgeColor: cError, onTap: () => _navigate(const NotificationPreferencesScreen())),
          _menuItem(icon: Icons.shield_outlined, title: 'Privacy & Security', onTap: () => _navigate(const PrivacySecurityScreen())),
          _menuItem(icon: Icons.help_outline_rounded, title: 'Help & Support', onTap: () => _navigate(const HelpSupportScreen())),
          _menuItem(icon: Icons.info_outline_rounded, title: 'About Tiba Safari', onTap: () => _navigate(const AboutScreen())),
        ]),
      ],
    );
  }

  Widget _menuGroup({required List<Widget> items}) {
    return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: cBorder), boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 4))]), child: Column(children: items));
  }

  Widget _menuItem({required IconData icon, required String title, String? badge, Color? badgeColor, required VoidCallback onTap}) {
    final isLast = title == 'About Tiba Safari' || title == 'Payment Methods' && badge != null;
    return Material(color: Colors.transparent, child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: cTealLight, borderRadius: BorderRadius.circular(13)), child: Icon(icon, size: 22, color: cTealDark)),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cTealDeep))),
          if (badge != null) ...[
            Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (badgeColor ?? cTeal).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(badge, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: badgeColor ?? cTeal))),
          ],
          const Icon(Icons.chevron_right_rounded, size: 20, color: cMutedLight),
        ]),
      ),
    ));
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _showLogoutDialog,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(color: cError.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(18), border: Border.all(color: cError.withValues(alpha: 0.2), width: 1.5)),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.logout_rounded, size: 20, color: cError), SizedBox(width: 10), Text('Log Out', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: cError))]),
      ),
    );
  }

  void _navigate(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}