import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/perf.dart';
import '../../core/utils/text_symbols.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/admin_shell.dart';
import '../../shared/widgets.dart';

Color _colorFromId(int id) {
  if (id <= 0) return const HSLColor.fromAHSL(1, 0, 0, 0.85).toColor();
  final hue = (id * 137.508) % 360;
  return HSLColor.fromAHSL(1, hue, 0.65, 0.85).toColor();
}

/// Mirrors `app/(admin)/admin/users/customers/[id]/page.tsx`.
class CustomerDetailScreen extends ConsumerStatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final int customerId;

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();

  Customer? _customer;
  List<Agent> _agents = const [];
  List<Order> _orders = const [];
  int? _agent;
  bool _loading = true;
  bool _saving = false;
  bool _isEditing = false;
  int _page = 1;
  int _totalOrders = 0;

  @override
  void initState() {
    super.initState();
    Perf.start('cust');
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
        repos.customer.getOne(widget.customerId),
        repos.agent.list(),
        repos.order.byCustomer(widget.customerId, page: _page),
      ]);
      if (!mounted) return;
      final c = results[0] as Customer;
      final agents = results[1] as List<Agent>;
      final page = results[2] as Paginated<Order>;
      final orders = page.results
          .where((o) => o.status != 'DRAFT')
          .toList();
      setState(() {
        _customer = c;
        _agents = agents;
        _orders = orders;
        _totalOrders = page.count;
        _agent = c.agent;
        _nameCtrl.text = c.name;
        _addressCtrl.text = c.address ?? '';
        _contactCtrl.text = c.contact ?? '';
        _gstCtrl.text = c.gst ?? '';
        _loading = false;
      });
      Perf.end('cust', 'TTC');
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasNext => _totalOrders > _page * 50;

  void _startEdit() {
    setState(() => _isEditing = true);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await repos.customer.update(widget.customerId, {
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'contact': _contactCtrl.text.trim(),
        'agent': _agent,
        'gst': _gstCtrl.text.trim().toUpperCase(),
      });
      if (!mounted) return;
      AppToast.success(context, 'Customer updated successfully');
      context.go('/admin/users');
    } catch (e) {
      if (mounted) {
        AppToast.error(context,
            e.toString().replaceFirst('Exception: ', ''));
      }
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final done = await showDialog<bool>(
      context: context,
      builder: (ctx) => DeleteWithTransferDialog(
        entityType: 'customer',
        entityName: _customer?.name ?? '',
        fetchDeleteInfo: () => repos.customer.deleteInfo(widget.customerId),
        onDelete: ({required pin, required action, transferToId}) async {
          await repos.customer.delete(widget.customerId, pin, action: action);
        },
      ),
    );
    if (mounted && done == true) {
      context.go('/admin/users');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      activePath: '/admin/users',
      body: _loading
          ? const PageLoading()
          : _customer == null
              ? const EmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'Customer not found.',
                )
              : _body(),
    );
  }

  Widget _body() {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/admin/users'),
              icon: const Icon(Icons.arrow_back, color: AppColors.heading),
            ),
            Expanded(
              child: Center(
                child: Column(
                  children: const [
                    Text('Customer Profile',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827))),
                    Text('MANAGE CLIENT RECORDS',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: _isEditing
                  ? () => setState(() => _isEditing = false)
                  : _startEdit,
              icon: Icon(
                _isEditing ? Icons.visibility_outlined : Icons.edit_outlined,
                size: 20,
                color: AppColors.heading,
              ),
            ),
            IconButton(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Color(0xFFDC2626)),
            ),
          ],
        ),
        Expanded(
          child: _isEditing ? _editForm() : _viewMode(),
        ),
      ],
    );
  }

  Widget _avatar(Color c, IconData icon, Color iconColor) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, size: 38, color: iconColor),
    );
  }

  Widget _viewMode() {
    final c = _customer!;
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        Center(
          child: Column(
            children: [
              _avatar(_colorFromId(c.id), Icons.person_outline,
                  const Color(0xFF4B5563)),
              const SizedBox(height: 10),
              Text(c.name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827))),
              Text('ID: #${c.id}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Column(
            children: [
              InfoRow('CONTACT', c.contact ?? kEmDash),
              InfoRow('ADDRESS', c.address ?? kEmDash),
              InfoRow('GST', c.gst ?? kEmDash),
              InfoRow('AGENT', c.agentName ?? kEmDash),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StockFlowButton(
          label: 'Create order',
          icon: const Icon(Icons.add, size: 16, color: Colors.white),
          onPressed: () => context.push('/admin/order/new?customer=${c.id}'),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 16, color: Color(0xFF9CA3AF)),
              SizedBox(width: 6),
              Text('ORDER HISTORY',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Color(0xFF9CA3AF))),
            ],
          ),
        ),
        if (_orders.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: const Center(
              child: Text('No orders yet',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF9CA3AF))),
            ),
          )
        else
          for (final o in _orders) _orderTile(o),
        if (_hasNext)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _page += 1);
                  _load();
                },
                child: const Text('Show More'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _orderTile(Order o) {
    final (dot, badgeBg, badgeFg) = switch (o.status) {
      'DISPATCHED' => (
          const Color(0xFF22C55E),
          const Color(0xFFDCFCE7),
          const Color(0xFF16A34A)),
      'PACKED' => (
          const Color(0xFF3B82F6),
          const Color(0xFFDBEAFE),
          const Color(0xFF2563EB)),
      'PENDING' => (
          const Color(0xFFEAB308),
          const Color(0xFFFEF9C3),
          const Color(0xFFCA8A04)),
      _ => (
          const Color(0xFFD1D5DB),
          const Color(0xFFF3F4F6),
          const Color(0xFF4B5563)),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/admin/order/status/${o.id}'),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text('Order #${o.id}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827))),
                      const SizedBox(width: 8),
                      Text(formatSets(o.totalSets),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(o.status ?? '',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeFg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editForm() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        Center(
          child: Column(
            children: [
              _avatar(
                  const HSLColor.fromAHSL(1, 150, 0.65, 0.92).toColor(),
                  Icons.person_outline,
                  AppColors.primary),
              const SizedBox(height: 10),
              Text(_nameCtrl.text.isEmpty ? 'New Customer' : _nameCtrl.text,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _editLabel('CUSTOMER NAME'),
              _editField(_nameCtrl),
              const SizedBox(height: 14),
              _editLabel('ASSIGNED AGENT'),
              DropdownButtonFormField<int?>(
                value: _agent,
                items: [
                  for (final a in _agents)
                    DropdownMenuItem(
                        value: a.id, child: Text(a.displayName)),
                ],
                onChanged: (v) => setState(() => _agent = v),
                decoration: _editDecoration(),
              ),
              const SizedBox(height: 14),
              _editLabel('SHIPPING ADDRESS'),
              _editField(_addressCtrl, minLines: 3, maxLines: 3),
              const SizedBox(height: 14),
              _editLabel('CONTACT DETAIL'),
              _editField(_contactCtrl),
              const SizedBox(height: 14),
              _editLabel('GST'),
              _editField(_gstCtrl),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StockFlowButton(
          label: _saving ? 'Saving Changes...' : 'Save Changes',
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }

  Widget _editLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: Color(0xFF9CA3AF))),
      );

  Widget _editField(TextEditingController c, {int? minLines, int? maxLines}) =>
      TextFormField(
        controller: c,
        minLines: minLines,
        maxLines: maxLines,
        decoration: _editDecoration(),
      );

  InputDecoration _editDecoration() => InputDecoration(
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