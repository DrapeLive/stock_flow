import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories.dart';
import 'widgets.dart';

/// Mirrors `app/(auth)/reset-password/page.tsx` (token passed as path segment).
class ResetScreen extends ConsumerStatefulWidget {
  const ResetScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends ConsumerState<ResetScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _success = false;
  int _shake = 0;
  String _error = '';
  String _passwordError = '';
  String _confirmError = '';

  bool get _hasToken => widget.token.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!_hasToken) {
      _error = 'Invalid or missing reset link. Please request a new one.';
      _shake++;
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _validate() {
    final errs = <String, String>{};
    if (_password.text.isEmpty) {
      errs['password'] = 'Password is required.';
    } else if (_password.text.length < 8) {
      errs['password'] = 'Must be at least 8 characters.';
    }
    if (_confirm.text.isEmpty) {
      errs['confirm'] = 'Please confirm your password.';
    } else if (_password.text != _confirm.text) {
      errs['confirm'] = 'Passwords do not match.';
    }
    setState(() {
      _passwordError = errs['password'] ?? '';
      _confirmError = errs['confirm'] ?? '';
    });
    if (errs.isNotEmpty) {
      _shake++;
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    setState(() => _error = '');
    if (!_validate()) return;
    setState(() => _loading = true);
    try {
      await repos.auth.resetPassword(widget.token, _password.text);
      setState(() => _success = true);
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
                if (_success)
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
                        'Password updated!',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.heading),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your password has been reset successfully. '
                        'You can now sign in with your new password.',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Go to sign in'),
                        ),
                      ),
                    ],
                  )
                else ...[
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set a new password',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.heading),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Must be at least 8 characters long.',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  if (_error.isNotEmpty) AuthAlert(message: _error),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PasswordField(
                        label: 'New password',
                        controller: _password,
                        error: _passwordError,
                        autofocus: _hasToken,
                        onChanged: (_) {},
                        onSubmitted: () => FocusScope.of(context).nextFocus(),
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        label: 'Confirm new password',
                        controller: _confirm,
                        error: _confirmError,
                        onSubmitted: _submit,
                      ),
                      const SizedBox(height: 20),
                      AuthSubmitButton(
                        loading: _loading,
                        icon: const Icon(Icons.key, size: 16, color: Colors.white),
                        label: 'Reset password',
                        loadingLabel: 'Updatingâ€¦',
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ],
                if (!_success)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.go('/login'),
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