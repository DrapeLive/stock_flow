import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/order_item_sort.dart';
import '../../core/utils/perf.dart';
import '../../core/utils/piece_counts.dart';
import '../../core/utils/status_maps.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

enum _OrderTab { packing, dispatching }

class OrderStatusScreen extends ConsumerStatefulWidget {
  const OrderStatusScreen({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends ConsumerState<OrderStatusScreen> {
  _OrderTab _tab = _OrderTab.packing;
  Order? _order;
  bool _loading = true;
  bool _packingMode = false;
  bool _deleting = false;
  bool _logsExpanded = false;
  bool _logsLoading = false;
  List<OrderLog> _logs = const [];
  List<Transport> _transports = const [];
  int? _dispatchTransport;
  String _lrNumber = '';
  String? _error;

  bool get _anyItemPacked => (_order?.items ?? const [])
      .any((item) => (item.packedQuantity ?? 0) > 0);

  bool get _isDeletable =>
      _order?.status == 'PENDING' || _order?.status == 'PACKED';

  bool get _isEditable => _order?.status == 'DRAFT' ||
      _order?.status == 'PENDING' ||
      _order?.status == 'PACKED';

@override
  void initState() {
    super.initState();
    Perf.start('ostatus');
    _load();
    _loadTransports();
  }

  Future<void> _loadTransports() async {
    try {
      final transports = await repos.transport.active();
      if (mounted) {
        setState(() {
          _transports = transports;
          final pref = _order?.preferredTransport;
          if (_dispatchTransport == null && pref != null &&
              transports.any((t) => t.id == pref)) {
            _dispatchTransport = pref;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final order = await repos.order.getOne(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          if (_tab == _OrderTab.packing && order.status == 'PACKED') {
            _tab = _OrderTab.dispatching;
          }
final pref = order.preferredTransport;
          if (pref != null && _dispatchTransport == null) {
            _dispatchTransport = pref;
          }
          _loading = false;
        });
        Perf.end('ostatus', 'TTC');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _logsLoading = true);
    try {
      final logs = await repos.order.getLogs(widget.orderId);
      if (mounted) setState(() => _logs = logs);
    } catch (_) {}
    if (mounted) setState(() => _logsLoading = false);
  }

  void _togglePackingMode() async {
    await _load();
    if (mounted) setState(() => _packingMode = !_packingMode);
  }

  Future<void> _togglePacked(OrderItem item) async {
    final totalPieces = (item.pieceCount ?? 1) * item.quantity;
    final currentPacked = item.packedQuantity ?? 0;
    final newPacked = currentPacked >= totalPieces ? 0 : totalPieces;

    if (_order?.status == 'PACKED' && newPacked < currentPacked) {
      final ok = await confirmDialog(
        context,
        title: 'Unpack Items?',
        message:
            'Order is currently marked as packed. Unpacking items will change the order status back to PENDING. Continue?',
        confirmLabel: 'Unpack',
      );
      if (!ok) return;
    }

    try {
      await repos.order.updateItem(
        item.id,
        {'packed_quantity': newPacked},
      );
      if (_order?.status == 'PACKED') {
        await repos.order.update(widget.orderId, {'status': 'PENDING'});
        if (mounted) {
          AppToast.success(context, 'Order status changed to PENDING');
        }
      }
      await _load();
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    }
  }

  Future<void> _deleteItem(OrderItem item) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove item?',
      message: 'This action cannot be undone.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    try {
      await repos.order.deleteItem(widget.orderId, item.id);
      await _load();
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await repos.order.update(widget.orderId, {'status': newStatus});
      await _load();
      if (mounted && newStatus == 'PACKED') {
        setState(() => _packingMode = false);
      }
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    }
  }

  Future<void> _showDispatchDialog() async {
    var transport = _dispatchTransport;
    var lr = _lrNumber;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Dispatch Order',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Unpacked items will be returned to the warehouse.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                value: transport,
                isExpanded: true,
                decoration: _fieldDecoration('Transport Company'),
                hint: const Text('Select Transport',
                    style: TextStyle(fontSize: 13)),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('Select Transport')),
                  for (final t in _transports)
                    DropdownMenuItem<int?>(value: t.id, child: Text(t.name)),
                ],
                onChanged: (v) => setDialogState(() => transport = v),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setDialogState(() => lr = v),
                decoration: _fieldDecoration('LR Number')
                    .copyWith(hintText: 'Enter LR number'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Dispatch'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _dispatchTransport = transport;
      _lrNumber = lr;
    });
    try {
      await repos.order.dispatch(
        widget.orderId,
        transportCompany: transport,
        lrNumber: lr.isEmpty ? null : lr,
      );
      if (mounted) AppToast.success(context, 'Order dispatched');
      if (mounted) context.go('/admin');
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
    }
  }

  Future<void> _deleteOrder() async {
    final pin = await PinDialog.show(
      context,
      title: 'Delete Order',
      message: 'Stock will be returned to inventory. This cannot be undone.',
    );
    if (pin == null) return;
    setState(() => _deleting = true);
    try {
      await repos.order.delete(widget.orderId, pin);
      if (mounted) AppToast.success(context, 'Order deleted successfully');
      if (mounted) context.go('/admin');
    } catch (e) {
      if (mounted) AppToast.error(context, e.toString());
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: PageLoading(label: 'Loading order #${widget.orderId}...'),
        ),
      );
    }
    final order = _order;
    if (order == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load order',
            subtitle: _error,
            action: Align(
              child: StockFlowButton(
                label: 'Retry',
                onPressed: _load,
expand: false,
              ),
            ),
          ),
        ),
      );
    }
    final items = order.items;
    final packedItems = items.where(isOrderItemFullyPacked).toList();
    final shownItems = sortOrderItemsUnpackedFirst(
        _tab == _OrderTab.dispatching ? packedItems : items);

return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _OrderDetailHeader(orderId: widget.orderId, onBack: () {
            context.canPop() ? context.pop() : context.go('/admin');
          }),
            OfflineBanner(),
            Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                _OrderTabs(
                  active: _tab,
                  onChanged: (t) => setState(() {
                    _tab = t;
                    _packingMode = false;
                  }),
                ),
                if (_isDeletable)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _OrderDeleteButton(
                        loading: _deleting,
                        onTap: _deleteOrder,
                      ),
                    ),
                  ),
                _OrderSummaryCard(order: order, transports: _transports),
                _ItemsHeader(
                  title: 'Items to ${_tab == _OrderTab.packing ? 'Packing' : 'Dispatching'}',
                  activeTab: _tab,
                  status: order.status,
                  isPackingMode: _packingMode,
                  onTogglePackingMode: _togglePackingMode,
                ),
                ...shownItems.map(
                  (item) => _OrderItemRowView(
                    item: item,
                    isPacking: _packingMode && _tab == _OrderTab.packing,
                    isEditable: _isEditable,
                    isDeletable: _isEditable,
                    onTogglePacked: () => _togglePacked(item),
                    onDelete: () => _deleteItem(item),
                    onEdit: () => _openEdit(item),
                  ),
                ),
                _OrderLogsSection(
                  expanded: _logsExpanded,
                  loading: _logsLoading,
                  logs: _logs,
                  onToggle: () {
                    setState(() => _logsExpanded = !_logsExpanded);
                    if (!_logsExpanded) _loadLogs();
                  },
),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _footer(order),
    );
  }

  Widget _footer(Order order) {
    final canDispatch = _anyItemPacked && order.status == 'PACKED';
    Widget? content;
    if (_tab == _OrderTab.packing &&
        _anyItemPacked &&
        order.status == 'PENDING' &&
        !_packingMode) {
      content = StockFlowButton(
        label: 'Complete Packing',
        icon: const Icon(Icons.assignment_turned_in_outlined,
            size: 18, color: Colors.white),
        onPressed: () => _updateStatus('PACKED'),
      );
    } else if (_tab == _OrderTab.dispatching && canDispatch) {
      content = StockFlowButton(
        label: 'Confirm Dispatch',
        icon:
            const Icon(Icons.local_shipping_outlined, size: 18, color: Colors.white),
        onPressed: _showDispatchDialog,
      );
    } else if (_tab == _OrderTab.dispatching && order.status == 'DISPATCHED') {
      content = const _FooterPill(
        color: Color(0xFF16A34A),
        bg: Color(0xFFF0FDF4),
        border: Color(0xFFBBF7D0),
        icon: Icons.check_circle_outline,
        label: 'Order has been dispatched',
      );
    } else if (_tab == _OrderTab.dispatching && order.status == 'PENDING') {
      content = const _FooterPill(
        color: Color(0xFFD97706),
        bg: Color(0xFFFEFCE8),
        border: Color(0xFFFDE68A),
        icon: Icons.info_outline,
        label: 'Pack some items before dispatching',
      );
    }
    if (content == null) return const SizedBox.shrink();
    final child = content is StockFlowButton
        ? content
        : Center(child: content);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: child,
      ),
    );
  }

  void _openEdit(OrderItem item) async {
    final result = await _OrderItemEditSheet.show(
      context,
      item: item,
      otherItems: _order?.items ?? const [],
    );
    if (result != null) {
      try {
        await repos.order.updateItem(item.id, result);
        await _load();
      } catch (e) {
        if (mounted) AppToast.error(context, e.toString());
      }
    }
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Color(0xFF9CA3AF),
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _OrderDetailHeader extends StatelessWidget {
  const _OrderDetailHeader({required this.orderId, required this.onBack});
  final int orderId;
  final VoidCallback onBack;

@override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 14, 16, 10),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onBack,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: const [
                  Icon(Icons.chevron_left, size: 20, color: AppColors.primary),
                  SizedBox(width: 2),
                  Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Order #$orderId',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDeleteButton extends StatelessWidget {
  const _OrderDeleteButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFEF4444)),
              )
            else
              const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
            const SizedBox(width: 6),
const Text(
              'Delete',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------------

class _OrderTabs extends StatelessWidget {
  const _OrderTabs({required this.active, required this.onChanged});
  final _OrderTab active;
  final ValueChanged<_OrderTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final tab in _OrderTab.values)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onChanged(tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: active == tab
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab == _OrderTab.packing
                            ? Icons.inventory_2_outlined
                            : Icons.local_shipping_outlined,
                        size: 14,
                        color: active == tab
                            ? Colors.white
                            : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab == _OrderTab.packing ? 'Packing' : 'Dispatching',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active == tab
                              ? Colors.white
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card
// ---------------------------------------------------------------------------

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order, required this.transports});
  final Order order;
  final List<Transport> transports;

  String _label(int? id) =>
      transports.firstWhere((t) => t.id == id, orElse: () => Transport(id: -1, name: '')).name;

  @override
  Widget build(BuildContext context) {
    final customer = order.customer;
    final agent = order.agent;
    final status = OrderStatus.from(order.status);
    final expected = order.expectedDeliveryDate ?? '';
    final preferred = _label(order.preferredTransport);
    final dispatchTransport = _label(order.transportCompany);
    final lrNumber = order.lrNumber ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryColumn(
                  label: 'Customer',
                  lines: [
                    customer.name,
                    customer.address ?? '',
                    customer.contact ?? '',
                    customer.gst ?? '',
                  ]..removeWhere((e) => e.isEmpty),
                ),
              ),
              Expanded(
                child: _SummaryColumn(
                  label: 'Agent',
                  lines: [agent.name, agent.contact ?? '']
                    ..removeWhere((e) => e.isEmpty),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryColumn(
                  label: 'Order Date',
                  lines: [order.createdAt.length >= 10
                      ? order.createdAt.substring(0, 10)
                      : order.createdAt],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SummaryLabel('Current Status'),
                    const SizedBox(height: 4),
                    StatusBadge(status),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: Color(0xFFF3F4F6)),
          Row(
            children: [
              Expanded(
                child: _SummaryColumn(
                  label: 'Expected Delivery',
                  lines: [expected.isEmpty ? 'Not specified' : formatDate(expected)],
                ),
              ),
              Expanded(
                child: _SummaryColumn(
                  label: 'Preferred Transport',
                  lines: [preferred.isEmpty ? 'Not specified' : preferred],
                ),
              ),
            ],
          ),
          if ((order.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            _SummaryColumn(label: 'Notes', lines: [order.notes!]),
          ],
          if (dispatchTransport.isNotEmpty || lrNumber.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  if (dispatchTransport.isNotEmpty)
                    Text.rich(TextSpan(
                      text: 'Transported by ',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500),
                      children: [
                        TextSpan(
                          text: dispatchTransport,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937)),
                        ),
                      ],
                    )),
                  if (dispatchTransport.isNotEmpty && lrNumber.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Color(0x1A000000)),
                    ),
                  if (lrNumber.isNotEmpty)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('LR number copied')),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'LR NUMBER',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lrNumber,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const Text('Tap to copy',
                                style: TextStyle(
                                    fontSize: 10, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryLabel extends StatelessWidget {
  const _SummaryLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF9CA3AF),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      );
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({required this.label, required this.lines});
  final String label;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryLabel(label),
        const SizedBox(height: 3),
        for (final line in lines)
          Text(
            line,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Items section
// ---------------------------------------------------------------------------

class _ItemsHeader extends StatelessWidget {
  const _ItemsHeader({
    required this.title,
    required this.activeTab,
    required this.status,
    required this.isPackingMode,
    required this.onTogglePackingMode,
  });
  final String title;
  final _OrderTab activeTab;
  final String? status;
  final bool isPackingMode;
  final VoidCallback onTogglePackingMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const Text(
                  'Manage order items below',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
          if (activeTab == _OrderTab.packing && status != 'DISPATCHED')
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTogglePackingMode,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isPackingMode
                      ? const Color(0xFF16A34A)
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPackingMode
                          ? Icons.check_circle_outline
                          : Icons.inventory_2_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPackingMode ? 'Done Selecting' : 'Update Packing',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderItemRowView extends StatelessWidget {
  const _OrderItemRowView({
    required this.item,
    required this.isPacking,
    required this.isEditable,
    required this.isDeletable,
    required this.onTogglePacked,
    required this.onDelete,
    required this.onEdit,
  });
  final OrderItem item;
  final bool isPacking;
  final bool isEditable;
  final bool isDeletable;
  final VoidCallback onTogglePacked;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final pieceCount = item.pieceCount ?? 1;
    final quantity = item.quantity;
    final totalPieces = quantity * pieceCount;
    final isPacked = (item.packedQuantity ?? 0) >= totalPieces;
    final price = num.tryParse(item.itemPrice ?? '') ?? 0;
    final image = item.toVariantImage();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: isPacked ? const Color(0xFFF0FDF4) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFF9FAFB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isPacking)
            InkWell(
              onTap: onTogglePacked,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  isPacked
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 24,
                  color: isPacked
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD1D5DB),
                ),
              ),
            ),
          if (isEditable)
            InkWell(
              onTap: onEdit,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.edit_outlined,
                    size: 17, color: AppColors.primary),
              ),
            ),
          if (isDeletable)
            InkWell(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.delete_outline,
                    size: 17, color: Color(0xFFEF4444)),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: (image?.isNotEmpty ?? false)
                ? () => showImagePreview(context, image)
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 48,
                child: AppImage(
                  image,
                  iconSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.displayName} ( Color #${item.variantDisplayOrder} )',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isPacked
                        ? const Color(0xFF15803D)
                        : const Color(0xFF111827),
                  ),
                ),
                Text(
                  'Size: ${item.displaySizeGroup ?? item.sizeGroup ?? 'N/A'}',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 4),
                Text.rich(TextSpan(
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isPacked
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF4B5563),
                  ),
                  children: [
                    TextSpan(text: '${formatSets(quantity)} Ã— ${formatPieces(pieceCount)} = '),
                    TextSpan(
                      text: '$totalPieces',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' pcs'),
                  ],
                )),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatInrInt(price),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                formatInrInt(price * quantity * pieceCount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logs
// ---------------------------------------------------------------------------

const Map<String, ({String label, Color bg, Color fg})> _actionStyles = {
  'ITEM_DELETED': (label: 'Item Deleted', bg: Color(0xFFFEF2F2), fg: Color(0xFFDC2626)),
  'ORDER_DELETED': (label: 'Order Deleted', bg: Color(0xFFFEF2F2), fg: Color(0xFFDC2626)),
  'ORDER_EDITED': (label: 'Order Edited', bg: Color(0xFFEFF6FF), fg: Color(0xFF2563EB)),
  'DISPATCHED': (label: 'Dispatched', bg: Color(0xFFF0FDF4), fg: Color(0xFF16A34A)),
};

class _OrderLogsSection extends StatelessWidget {
  const _OrderLogsSection({
    required this.expanded,
    required this.loading,
    required this.logs,
    required this.onToggle,
  });
  final bool expanded;
  final bool loading;
  final List<OrderLog> logs;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty && !loading) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Color(0xFFF3F4F6)),
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 16, color: Color(0xFF4B5563)),
                  const SizedBox(width: 8),
                  const Text(
                    'View Activity Logs',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4B5563)),
                  ),
                  const Spacer(),
                  Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16, color: Color(0xFF4B5563)),
                ],
              ),
            ),
          ),
          if (expanded)
            ...(loading
                ? [
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Loading logs...',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF9CA3AF))),
                    ),
                  ]
                : logs.map((log) => _LogTile(log: log)).toList()),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});
  final OrderLog log;

  @override
  Widget build(BuildContext context) {
    final style = _actionStyles[log.action] ??
        (label: log.action ?? '', bg: const Color(0xFFF9FAFB), fg: const Color(0xFF4B5563));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  style.label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: style.fg),
                ),
              ),
              Text(
                formatDateTime(log.createdAt),
                style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          if ((log.performedBy ?? '').isNotEmpty)
            Text('By: ${log.performedBy}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer pill
// ---------------------------------------------------------------------------

class _FooterPill extends StatelessWidget {
  const _FooterPill({
    required this.bg,
    required this.border,
    required this.icon,
    required this.label,
    this.color = const Color(0xFF16A34A),
  });
  final Color bg;
  final Color border;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit item sheet
// ---------------------------------------------------------------------------

class _OrderItemEditSheet extends StatefulWidget {
  const _OrderItemEditSheet({required this.item, required this.otherItems});
  final OrderItem item;
  final List<OrderItem> otherItems;

  static Future<Map<String, dynamic>?> show(BuildContext context,
      {required OrderItem item, required List<OrderItem> otherItems}) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          _OrderItemEditSheet(item: item, otherItems: otherItems),
    );
  }

  @override
  State<_OrderItemEditSheet> createState() => _OrderItemEditSheetState();
}

class _OrderItemEditSheetState extends State<_OrderItemEditSheet> {
  int _quantity = 1;
  String _sizeGroup = '';
  List<String> _groups = [];
  List<VariantSize> _variantSizes = [];
  bool _loadingVariants = true;
  String? _groupError;
  String? _quantityError;
  String _pieceCount = '1';

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _quantity = item.quantity;
    _sizeGroup = item.sizeGroup ?? '';
    _pieceCount = (item.pieceCount ?? 1).toString();
    _loadVariants();
  }

  Future<void> _loadVariants() async {
    setState(() => _loadingVariants = true);
    try {
      final variants = await repos.item.allVariants();
      final target = widget.item.variant;
      final variant = variants.firstWhere(
        (v) => v.id == target,
        orElse: () => VariantAllItem(
          id: target ?? -1,
          itemId: 0,
          itemName: '',
          itemType: '',
          itemPrice: '',
          sizes: const [],
          totalStock: 0,
          uniqueSizes: const [],
        ),
      );

      final itemType = (widget.item.item?.type ?? 'gents').toLowerCase();
      final validType = (itemType == 'kids' || itemType == 'gents')
          ? itemType
          : 'gents';

      final sizeRanges = await repos.item.sizeRanges();
      final byType = (sizeRanges['order_creation_sizes_by_type']
              as Map<String, dynamic>? ??
          {});
final orderGroups = List<String>.from(
          byType[validType] as List<dynamic>? ?? const []);

      final variantSizeSet = variant.sizes.map((s) => s.sizeRange).toSet();
      final groups = orderGroups
          .where((range) =>
              (kSizeRangeToSizes[range] ?? const []).every(
                  (bucket) => variantSizeSet.contains(bucket)))
          .toList();

      final groupedPieceCount = pieceCountFor(_sizeGroup);
      final resolvedPieceCount = groupedPieceCount > 0
          ? groupedPieceCount
          : (widget.item.pieceCount ?? 1);
      if (mounted) {
        setState(() {
          _groups = groups;
          _variantSizes = variant.sizes;
          _pieceCount = resolvedPieceCount.toString();
          if (groups.isEmpty) {
            _groupError = 'No sizes available for this variant';
          } else if (_sizeGroup.isNotEmpty && !groups.contains(_sizeGroup)) {
            _groupError = 'Current size group is no longer available';
          }
          _loadingVariants = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVariants = false);
    }
  }

  int _availableStock() {
    final buckets = kSizeRangeToSizes[_sizeGroup] ?? const <String>[];
    if (buckets.isEmpty) return 0;
    final remaining = buckets.map((bucket) {
      final base = _variantSizes
              .firstWhere((s) => s.sizeRange == bucket,
                  orElse: () => VariantSize(sizeRange: bucket, stock: 0))
              .stock;
      final reserved = widget.otherItems
          .where((o) =>
              o.id != widget.item.id &&
              o.variant == widget.item.variant &&
              o.item == widget.item.item)
          .fold(0, (sum, o) {
        final covers = kSizeRangeToSizes[o.sizeGroup] ?? const <String>[];
        return sum + (covers.contains(bucket) ? o.quantity : 0);
      });
      return base - reserved;
    }).toList();
    final minRemaining =
        remaining.isEmpty ? 0 : remaining.reduce((a, b) => a < b ? a : b);
    return minRemaining < 0 ? 0 : minRemaining;
  }

  void _save() {
    final errors = <String, String>{};
    if (_quantity < 1) {
      errors['qty'] = 'Quantity must be at least 1';
    }
    if (_sizeGroup.isEmpty) {
      errors['group'] = 'Please select a size group';
    } else if (_availableStock() < _quantity) {
      errors['qty'] =
          'Only ${_availableStock()} sets available for this size group';
    }
    setState(() {
      _groupError = errors['group'];
      _quantityError = errors['qty'];
    });
    if (errors.isNotEmpty) return;

    final packed = (widget.item.packedQuantity ?? 0);
    final newPacked = packed > _quantity * int.parse(_pieceCount)
        ? _quantity * int.parse(_pieceCount)
        : packed;
    Navigator.pop(context, {
      'quantity': _quantity,
      'size_group': _sizeGroup,
      'packed_quantity': newPacked,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit ${widget.item.displayName}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827)),
              ),
              const SizedBox(height: 16),
              if (_loadingVariants)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ))
              else ...[
                Row(
                  children: [
                    InkWell(
                      onTap: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                      child: const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFFF3F4F6),
                        foregroundColor: Color(0xFF4B5563),
                        child: Icon(Icons.remove, size: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$_quantity',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => setState(() => _quantity++),
                      child: const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.add, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Set${_quantity == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF4B5563))),
                  ],
                ),
                if (_quantityError != null) ...[
                  const SizedBox(height: 6),
                  Text(_quantityError!,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFEF4444))),
                ],
                const SizedBox(height: 16),
                Text('Size Group',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _groups.contains(_sizeGroup) ? _sizeGroup : null,
                  isExpanded: true,
                  items: [
                    for (final g in _groups)
                      DropdownMenuItem<String>(
                          value: g, child: Text(g)),
                  ],
                  decoration: _EditFieldDecoration().decoration(),
                  hint: const Text('Select size group'),
                  onChanged: (v) => setState(() {
                    _sizeGroup = v ?? '';
                    final pc = pieceCountFor(_sizeGroup);
                    if (pc > 1) _pieceCount = pc.toString();
                  }),
                ),
                if (_groupError != null) ...[
                  const SizedBox(height: 6),
                  Text(_groupError!,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFEF4444))),
                ],
                const SizedBox(height: 16),
                Text('$_pieceCount pcs per set',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: StockFlowButton(
                    label: 'Save Changes',
                    onPressed: _save,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditFieldDecoration {
  InputDecoration decoration() => InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}