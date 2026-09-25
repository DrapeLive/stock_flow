import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers.dart';
import 'widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  int _shake = 0;
  String _errorTitle = '';
  String _errorSub = '';
  bool _warn = false;
  String _emailError = '';
  String _passwordError = '';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validate() {
    final errs = <String, String>{};
    if (_email.text.trim().isEmpty) errs['email'] = 'Email is required';
    if (_password.text.isEmpty) errs['password'] = 'Password is required';
    setState(() {
      _emailError = errs['email'] ?? '';
      _passwordError = errs['password'] ?? '';
    });
    if (errs.isNotEmpty) {
      _shake++;
      return false;
    }
    return true;
  }

  void _classify(Object error) {
    final msg = error.toString();
    final isNet = msg.toLowerCase().contains('network') || msg.toLowerCase().contains('connection');
    if (isNet) {
      _errorTitle = 'No internet connection';
      _errorSub = 'Check your connection and try again.';
      _warn = false;
    } else if (msg.toLowerCase().contains('password') || msg.toLowerCase().contains('invalid credentials')) {
      _errorTitle = 'Wrong password';
      _errorSub = 'Double-check your password and try again.';
      _warn = false;
    } else if (msg.toLowerCase().contains('email') || msg.toLowerCase().contains('no account') || msg.toLowerCase().contains('not found')) {
      _errorTitle = 'No account found for this email';
      _errorSub = '';
      _warn = false;
    } else if (msg.toLowerCase().contains('admin')) {
      _errorTitle = 'Admin access only';
      _errorSub = 'Only admin accounts can use this app for now.';
      _warn = true;
    } else {
      _errorTitle = 'Sign-in failed';
      _errorSub = 'Something went wrong. Please try again.';
      _warn = false;
    }
  }

  Future<void> _login() async {
    setState(() {
      _errorTitle = '';
      _errorSub = '';
    });
    if (!_validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(sessionProvider.notifier).login(
            _email.text.trim(),
            _password.text,
          );
      // Router redirects to /admin automatically.
    } catch (e) {
      _classify(e);
      setState(() => _shake++);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: AuthCard(
              shake: _shake > 0,
              children: [
                const AuthBranding(),
                if (_errorTitle.isNotEmpty)
                  AuthAlert(
                    message: _errorTitle,
                    sub: _errorSub,
                    warn: _warn,
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('Email address'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'example@gmail.com',
                        errorText: _emailError.isEmpty ? null : _emailError,
                      ),
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 18),
                    PasswordField(
                      label: 'Password',
                      controller: _password,
                      error: _passwordError,
                      onSubmitted: () => _login(),
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 24),
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(fontSize: 12, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AuthSubmitButton(
                      loading: _loading,
                      icon: const Icon(Icons.login, size: 18, color: Colors.white),
                      label: 'Sign in',
                      loadingLabel: 'Signing in…',
                      onPressed: _login,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );
}