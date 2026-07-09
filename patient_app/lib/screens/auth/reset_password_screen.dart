import 'dart:async';

import 'package:flutter/material.dart';
import 'package:patient_app/core/services/auth_service.dart';
import 'package:patient_app/core/theme/colors.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _step = 0; // 0 = request code, 1 = enter code + new password
  bool _isSubmitting = false;
  bool _isResending = false;
  bool _obscurePassword = true;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
      await AuthService().requestPasswordReset(email: _emailController.text.trim());
      if (!mounted) return;
      setState(() => _step = 1);
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('If that email exists, a code has been sent'), backgroundColor: cGreenDark),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: cError),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);
    try {
      await AuthService().requestPasswordReset(email: _emailController.text.trim());
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent'), backgroundColor: cGreenDark),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: cError),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _confirmReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await AuthService().confirmPasswordReset(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset — please sign in'), backgroundColor: cGreenDark),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: cError),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: cBlue),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: cField,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cBlue, width: 2)),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: cBorder),
                  boxShadow: const [
                    BoxShadow(blurRadius: 18, spreadRadius: 1, offset: Offset(0, 8), color: Color.fromRGBO(47, 143, 239, 0.12)),
                  ],
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
                            icon: const Icon(Icons.arrow_back_rounded, color: cInk),
                          ),
                        ],
                      ),
                      Text(
                        _step == 0 ? 'Forgot password?' : 'Reset your password',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cInk),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _step == 0
                            ? 'Enter your email and we\'ll send you a reset code'
                            : 'Enter the code sent to ${_emailController.text.trim()} and choose a new password',
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
        controller: _emailController,
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
          style: ElevatedButton.styleFrom(backgroundColor: cBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _isSubmitting ? null : _requestCode,
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Send reset code', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
    ];
  }

  List<Widget> _buildConfirmStep() {
    return [
      TextFormField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 6, color: cInk),
        decoration: _decoration('000000', Icons.pin_outlined).copyWith(counterText: ''),
        validator: (v) {
          final s = v?.trim() ?? '';
          if (s.length != 6 || int.tryParse(s) == null) return 'Enter the 6-digit code';
          return null;
        },
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _newPasswordController,
        obscureText: _obscurePassword,
        decoration: _decoration(
          'New password',
          Icons.lock_outline_rounded,
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: cMuted, size: 20),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        validator: (v) {
          if (v == null || v.length < 8) return 'At least 8 characters required';
          return null;
        },
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _confirmPasswordController,
        obscureText: _obscurePassword,
        decoration: _decoration('Confirm new password', Icons.lock_outline_rounded),
        validator: (v) {
          if (v != _newPasswordController.text) return 'Passwords do not match';
          return null;
        },
      ),
      const SizedBox(height: 20),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: cBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _isSubmitting ? null : _confirmReset,
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Reset password', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: (_isResending || _cooldownSeconds > 0) ? null : _resendCode,
        child: Text(
          _cooldownSeconds > 0 ? 'Resend code (${_cooldownSeconds}s)' : 'Resend code',
          style: const TextStyle(color: cBlueDark, fontWeight: FontWeight.w600),
        ),
      ),
    ];
  }
}
