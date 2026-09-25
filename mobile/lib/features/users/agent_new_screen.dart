import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/derive_username.dart';
import '../../data/repositories.dart';
import '../../shared/admin_shell.dart';
import '../../shared/widgets.dart';

/// Mirrors `app/(admin)/admin/users/agents/new/page.tsx`.
class AgentNewScreen extends ConsumerStatefulWidget {
  const AgentNewScreen({super.key});

  @override
  ConsumerState<AgentNewScreen> createState() => _AgentNewScreenState();
}

class _AgentNewScreenState extends ConsumerState<AgentNewScreen> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  Set<String> _existingUsernames = const {};
  bool _submitting = false;

  static final _emailRegex = RegExp(r'^\S+@\S+\.\S+$');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final agents = await repos.agent.list();
      if (!mounted) return;
      setState(() {
        _existingUsernames =
            agents.map((a) => a.user.username ?? '').where((u) => u.isNotEmpty).toSet();
      });
    } catch (_) {}
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    return null;
  }

  String? _validateEmail(String? v) {
    final val = v ?? '';
    if (val.trim().isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(val)) return 'Invalid email format';
    return null;
  }

  String? _validatePassword(String? v) {
    final val = v ?? '';
    if (val.trim().isEmpty) return 'Password is required';
    if (val.length < 6) return 'Minimum 6 characters required';
    return null;
  }

  String? _validateContact(String? v) {
    if (v == null || v.trim().isEmpty) return 'Contact number is required';
    return null;
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final username =
          deriveUsername(_nameCtrl.text, existingUsernames: _existingUsernames);
      final agent = await repos.agent.create({
        'username': username,
        'display_name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'contact': _contactCtrl.text.trim(),
        'password': _passwordCtrl.text,
      });
      if (!mounted) return;
      AppToast.success(context, 'Agent created successfully');
      context.pushReplacement('/admin/users/agents/${agent.id}');
    } catch (e) {
      if (mounted) {
        AppToast.error(context,
            e.toString().replaceFirst('Exception: ', ''));
      }
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      activePath: '/admin/users',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Agent',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827))),
                SizedBox(height: 2),
                Text('Create a new field agent account',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _form,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: ListView(
                  children: [
                    _label('DISPLAY NAME'),
                    TextFormField(
                      controller: _nameCtrl,
                      validator: _validateName,
                      decoration: _fieldDecoration(hint: 'e.g. John Doe'),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_nameCtrl.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text.rich(TextSpan(
                          text: 'Username: ',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF)),
                          children: [
                            TextSpan(
                              text: deriveUsername(_nameCtrl.text,
                                  existingUsernames: _existingUsernames),
                              style: const TextStyle(
                                  color: Color(0xFF4B5563),
                                  fontFamily: 'monospace'),
                            ),
                          ],
                        )),
                      ),
                    const SizedBox(height: 16),
                    _label('EMAIL ADDRESS'),
                    TextFormField(
                      controller: _emailCtrl,
                      validator: _validateEmail,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          _fieldDecoration(hint: 'agent@example.com'),
                    ),
                    const SizedBox(height: 16),
                    _label('SECURE PASSWORD'),
                    TextFormField(
                      controller: _passwordCtrl,
                      validator: _validatePassword,
                      obscureText: true,
                      decoration: _fieldDecoration(
                          hint: 'Minimum 6 characters'),
                    ),
                    const SizedBox(height: 16),
                    _label('CONTACT DETAIL'),
                    TextFormField(
                      controller: _contactCtrl,
                      validator: _validateContact,
                      keyboardType: TextInputType.phone,
                      decoration: _fieldDecoration(hint: '+91 xxxxx xxxxx'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/admin/users'),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: StockFlowButton(
                    label: _submitting ? 'Creating...' : 'Create Agent',
                    loading: _submitting,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: Color(0xFF9CA3AF))),
      );

  InputDecoration _fieldDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primary)),
      );
}