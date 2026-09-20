import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories.dart';
import '../../core/theme/app_theme.dart';
import 'widgets.dart';

/// Mirrors `app/(auth)/forgot-password/page.tsx`.
class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key});

  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  int _shake = 0;
  String _error = '';

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = '');
    if (_email.text.trim().isEmpty) {
      setState(() {
        _error = 'Please enter your email address.';
        _shake++;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      await repos.auth.forgotPassword(_email.text.trim().toLowerCase());
      setState(() => _sent = true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _shake++;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: AuthCard(
              shake: _shake > 0,
              children: [
                const AuthBranding(),
                if (_sent)
                  Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0FDF4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_outline,
                            size: 30, color: Color(0xFF22C55E)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Check your inbox',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.heading),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'If ${_email.text.trim()} is linked to an account, '
                        "you'll receive a reset link shortly.",
                        style:
                            const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() {
                          _sent = false;
                          _email.clear();
                        }),
                        child: const Text(
                          "Didn't get it? Check your spam folder or try again.",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Forgot your password?',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.heading),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Enter your email and we'll send you a reset link.",
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  if (_error.isNotEmpty) AuthAlert(message: _error),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Email address',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(hintText: 'example@gmail.com'),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 20),
                      AuthSubmitButton(
                        loading: _loading,
                        icon: const Icon(Icons.send, size: 16, color: Colors.white),
                        label: 'Send reset link',
                        loadingLabel: 'Sendingâ€¦',
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/login'),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back to login'),
                  ),
                ),
              ],
            ),
),
        ),
      ),
    );
  }
}