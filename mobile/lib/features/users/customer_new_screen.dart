import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/admin_shell.dart';
import '../../shared/widgets.dart';

/// Mirrors `app/(admin)/admin/users/customers/new/page.tsx`.
class CustomerNewScreen extends ConsumerStatefulWidget {
  const CustomerNewScreen({super.key});

  @override
  ConsumerState<CustomerNewScreen> createState() => _CustomerNewScreenState();
}

class _CustomerNewScreenState extends ConsumerState<CustomerNewScreen> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();

  List<Agent> _agents = const [];
  List<Transport> _transports = const [];
  int? _agent;
  int? _transport;
  bool _loading = true;
  bool _submitting = false;

  static final _gstRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
  static final _contactRegex = RegExp(r'^\+?[\d\s\-]{10,}$');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _contactCtrl.dispose();
    _gstCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        repos.agent.list(),
        repos.transport.active(),
      ]);
      if (!mounted) return;
      setState(() {
        _agents = results[0] as List<Agent>;
        _transports = results[1] as List<Transport>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Customer name is required';
    return null;
  }

  String? _validateAddress(String? v) {
    if (v == null || v.trim().isEmpty) return 'Address is required';
    return null;
  }

  String? _validateContact(String? v) {
    final val = v ?? '';
    if (val.trim().isEmpty) return 'Contact number is required';
    if (!_contactRegex.hasMatch(val)) return 'Invalid contact number format';
    return null;
  }

  String? _validateGst(String? v) {
    final val = v ?? '';
    if (val.trim().isEmpty) return 'GST number is required';
    if (!_gstRegex.hasMatch(val.toUpperCase())) {
      return 'Invalid GST format (e.g. 29ABCDE1234F1Z5)';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_agent == null) {
      AppToast.error(context, 'Please select an agent');
      return;
    }
    setState(() => _submitting = true);
    try {
      await repos.customer.create({
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'contact': _contactCtrl.text.trim(),
        'agent': _agent,
        'gst': _gstCtrl.text.trim().toUpperCase(),
        'preferred_transport': _transport,
      });
      if (!mounted) return;
      AppToast.success(context, 'Customer created successfully');
      context.go('/admin/users');
    } catch (e) {
      if (mounted) {
        AppToast.error(context,
            e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
                Text('New Customer',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827))),
                SizedBox(height: 2),
                Text('Register a new client in the system',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: PageLoading())
          else
            Expanded(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF3F4F6)),
                    ),
                    child: Form(
                      key: _form,
                      child: Column(
                        children: [
                          _label('Assigned Agent'),
                          DropdownButtonFormField<int?>(
                            value: _agent,
                            hint: const Text('Select agent...'),
                            items: [
                              for (final a in _agents)
                                DropdownMenuItem(
                                    value: a.id, child: Text(a.displayName)),
                            ],
                            decoration: _fieldDecoration(),
                            onChanged: (v) => setState(() => _agent = v),
                          ),
                          const SizedBox(height: 16),
                          _label('Customer / Shop Name'),
                          TextFormField(
                            controller: _nameCtrl,
                            validator: _validateName,
                            decoration: _fieldDecoration(
                                hint: 'e.g. Fashion Hub'),
                          ),
                          const SizedBox(height: 16),
                          _label('Shipping Address'),
                          TextFormField(
                            controller: _addressCtrl,
                            validator: _validateAddress,
                            minLines: 3,
                            maxLines: 3,
                            decoration: _fieldDecoration(
                                hint: 'Full mailing address...'),
                          ),
                          const SizedBox(height: 16),
                          _label('Contact detail'),
                          TextFormField(
                            controller: _contactCtrl,
                            validator: _validateContact,
                            keyboardType: TextInputType.phone,
                            decoration:
                                _fieldDecoration(hint: '+91 98765 43210'),
                          ),
                          const SizedBox(height: 16),
                          _label('GST Number'),
                          TextFormField(
                            controller: _gstCtrl,
                            validator: _validateGst,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _fieldDecoration(
                                hint: 'e.g. 29ABCDE1234F1Z5'),
                          ),
                          const SizedBox(height: 16),
                          _label('Preferred Transport'),
                          DropdownButtonFormField<int?>(
                            value: _transport,
                            hint: const Text('None'),
                            items: [
                              const DropdownMenuItem<int?>(
                                  value: null, child: Text('None')),
                              for (final t in _transports)
                                DropdownMenuItem(
                                    value: t.id, child: Text(t.name)),
                            ],
                            decoration: _fieldDecoration(),
                            onChanged: (v) => setState(() => _transport = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                    label: _submitting ? 'Creating...' : 'Add Customer',
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