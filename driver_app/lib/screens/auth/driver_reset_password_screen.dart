import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../services/driver_service.dart';

class DriverResetPasswordScreen extends StatefulWidget {
  const DriverResetPasswordScreen({super.key});

  @override
  State<DriverResetPasswordScreen> createState() =>
      _DriverResetPasswordScreenState();
}

class _DriverResetPasswordScreenState extends State<DriverResetPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _step = 0; // 0 = request code, 1 = enter code + new password
  bool _isSubmitting = false;
  bool _isResending = false;
  bool _obscure = true;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _requestCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await DriverService.instance
          .requestPasswordReset(email: _emailCtrl.text.trim());
      if (!mounted) return;
      setState(() => _step = 1);
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('If that email exists, a code has been sent'),
        backgroundColor: cTeal,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: cError,
      ));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);
    try {
      await DriverService.instance
          .requestPasswordReset(email: _emailCtrl.text.trim());
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('A new code has been sent'),
        backgroundColor: cTeal,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: cError,
      ));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _confirmReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await DriverService.instance.confirmPasswordReset(
        email: _emailCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        newPassword: _newPasswordCtrl.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password reset — please sign in'),
        backgroundColor: cTeal,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: cError,
      ));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: cTeal),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: cSurface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cTeal, width: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: cBorder),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (_step == 1) {
                                setState(() => _step = 0);
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(Icons.arrow_back_rounded, color: cText),
                          ),
                        ],
                      ),
                      Text(
                        _step == 0 ? 'Forgot password?' : 'Reset your password',
                        textAlign: TextAlign.center,
                        style: AppFonts.sora(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _step == 0
                            ? 'Enter your email and we\'ll send you a reset code'
                            : 'Enter the code sent to ${_emailCtrl.text.trim()} and choose a new password',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: cMuted, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 22),
                      if (_step == 0) ..._buildRequestStep() else ..._buildConfirmStep(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRequestStep() {
    return [
      TextFormField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: _decoration('Email', Icons.alternate_email),
        validator: (v) {
          final s = v?.trim() ?? '';
          if (s.isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s)) {
            return 'Enter a valid email address';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: cTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _isSubmitting ? null : _requestCode,
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Send reset code',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
    ];
  }

  List<Widget> _buildConfirmStep() {
    return [
      TextFormField(
        controller: _codeCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 6, color: cText),
        decoration: _decoration('000000', Icons.pin_outlined).copyWith(counterText: ''),
        validator: (v) {
          final s = v?.trim() ?? '';
          if (s.length != 6 || int.tryParse(s) == null) return 'Enter the 6-digit code';
          return null;
        },
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _newPasswordCtrl,
        obscureText: _obscure,
        decoration: _decoration(
          'New password',
          Icons.lock_outline_rounded,
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: cMuted, size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        validator: (v) {
          if (v == null || v.length < 6) return 'At least 6 characters required';
          return null;
        },
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _confirmPasswordCtrl,
        obscureText: _obscure,
        decoration: _decoration('Confirm new password', Icons.lock_outline_rounded),
        validator: (v) {
          if (v != _newPasswordCtrl.text) return 'Passwords do not match';
          return null;
        },
      ),
      const SizedBox(height: 20),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: cTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _isSubmitting ? null : _confirmReset,
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Reset password',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: (_isResending || _cooldownSeconds > 0) ? null : _resendCode,
        child: Text(
          _cooldownSeconds > 0 ? 'Resend code (${_cooldownSeconds}s)' : 'Resend code',
          style: const TextStyle(color: cTealDark, fontWeight: FontWeight.w600),
        ),
      ),
    ];
  }
}
