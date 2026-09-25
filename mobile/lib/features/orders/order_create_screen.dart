import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/router/route_observer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/perf.dart';
import '../../core/utils/text_symbols.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';
import 'order_flow_utils.dart';

class _LoadError {
  const _LoadError.notfound()
      : notfound = true,
        message = null;
  const _LoadError.error(this.message) : notfound = false;
  final bool notfound;
  final String? message;
}

/// Step 2 - order details + item list. Mirrors the agent
/// `order/new/[id]/page.tsx` shared by the admin flow.
///
/// When [editOrderId] is set the same cart is reused to edit an existing
/// (placed) order instead of building a draft: the order details + item rows
/// + totals all behave identically, only the footer action ("Save Order") and
/// the header differ.
class OrderCreateScreen extends ConsumerStatefulWidget {
  const OrderCreateScreen({
    super.key,
    required this.customerId,
    this.editOrderId,
  });

  final int customerId;

  /// When set, this screen edits the given existing order instead of the
  /// draft in [OrderDraftSession]. [customerId] is ignored in this mode (the
  /// order's own customer is used).
  final int? editOrderId;

  @override
  ConsumerState<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends ConsumerState<OrderCreateScreen>
    with RouteAware {
  final _notesController = TextEditingController();
  Timer? _saveDebounce;

  Customer? _customer;
  Order? _order;
  List<Transport> _transports = const [];
  _LoadError? _loadError;
  bool _loading = true;
  bool _placing = false;

  DateTime? _expectedDate;
  int? _preferredTransport;
  String _notes = '';
  bool _ready = false;

  bool get _isEdit => widget.editOrderId != null;

  /// Order id the cart operates on: the draft in the session (create flow) or
  /// the fixed order id (edit flow).
  int? get _orderId => _isEdit ? widget.editOrderId : OrderDraftSession.orderId;

  /// Customer id used to build the scanner/search/picker routes. For edits the
  /// route's [Widget.customerId] is a placeholder, so the order's own customer
  /// is used.
  int get _effectiveCustomerId =>
      _isEdit ? (_order?.customer.id ?? 0) : widget.customerId;

  /// True while this cart owns a server-side edit transaction, i.e. the status
  /// screen already called `start-edit` and the order is now EDITING. Field
  /// changes are then committed by `save-edit` instead of a plain PATCH, and
  /// leaving without finishing releases the order with `cancel-edit`.
  bool get _isEditingSession =>
      _isEdit && (OrderDraftSession.orderId == _orderId) &&
      _order?.status?.toUpperCase() == 'EDITING';

  bool _editCommitted = false;

  /// Keeps the shared draft session pinned to the order this cart edits, so
  /// the reused scanner/search pickers add items to the very order whose edit
  /// transaction was opened.
  void _syncDraftSession() {
    if (!_isEdit) return;
    final orderId = widget.editOrderId;
    if (orderId == null) return;
    if (OrderDraftSession.orderId != orderId) {
      OrderDraftSession.start(
        orderId: orderId,
        customerId: _effectiveCustomerId,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    Perf.start('ocreate');
    _load();
    _loadTransports();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _saveDebounce?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  /// Re-fetch the draft whenever the scanner/item picker above pops back to
  /// this screen so a freshly added or updated line (and the total sets /
  /// pieces / value derived from it) shows immediately. Without this the
  /// screen would keep showing its stale, still-empty initState snapshot.
  @override
  void didPopNext() {
    _reloadOrder();
  }

  Future<void> _loadTransports() async {
    try {
      final transports = await repos.transport.active();
      if (mounted) setState(() => _transports = transports);
    } catch (_) {}
  }

Future<void> _load() async {
    final orderId = _orderId;
    if (orderId == null) {
      setState(() {
        _loadError = const _LoadError.notfound();
        _loading = false;
      });
      return;
    }
    try {
      // In edit mode the customer is resolved from the order itself (the route
      // only carries the order id), so fetch it first.
      final editOrder =
          _isEdit ? await repos.order.getOne(orderId) : null;
      final customerId =
          _isEdit ? editOrder!.customer.id : widget.customerId;
      OrderDraftSession.start(orderId: orderId, customerId: customerId);

      final results = await Future.wait([
        repos.customer.getOne(customerId),
        _isEdit
            ? Future<Order>.value(editOrder!)
            : repos.order.getOne(orderId),
      ]);
      if (!mounted) return;
      final customer = results[0] as Customer;
      final order = results[1] as Order;
      setState(() {
        _customer = customer;
        _order = order;
        _preferredTransport =
            order.preferredTransport ?? customer.preferredTransport;
        _expectedDate = DateTime.tryParse(order.expectedDeliveryDate ?? '');
        _notes = order.notes ?? '';
        _notesController.text = _notes;
_ready = true;
        _loading = false;
        _loadError = null;
      });
      Perf.end('ocreate', 'TTC');
    } catch (e) {
      if (!mounted) return;
      final api = ApiClient.mapError(e);
      setState(() {
        _loadError = api.statusCode == 404
            ? const _LoadError.notfound()
            : _LoadError.error(api.message);
        _loading = false;
      });
    }
  }

  void _scheduleSave() {
    if (!_ready) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _saveFields);
  }

  Future<void> _saveFields() async {
    if (_isEditingSession) return;
    final orderId = _orderId;
    if (orderId == null) return;
    try {
      await repos.order.update(orderId, {
        'expected_delivery_date':
            _expectedDate == null ? null : toApiDate(_expectedDate!),
        'preferred_transport': _preferredTransport,
        'notes': _notes.isEmpty ? null : _notes,
      });
    } catch (_) {}
  }

  List<OutOfStockItem> _outOfStockItems(dynamic data) {
    if (data is Map && data['out_of_stock_items'] is List) {
      return asList(data['out_of_stock_items'], OutOfStockItem.fromJson);
    }
    return const [];
  }

  /// Finishes editing an existing order. When an edit transaction is open the
  /// whole order is committed through `save-edit` (which also releases the
  /// EDITING hold); otherwise a plain field update is flushed as before.
  Future<void> _finishEdit() async {
    _saveDebounce?.cancel();
    final orderId = _orderId;
    if (orderId == null) return;
    if (_isEditingSession) {
      if (_placing) return;
      setState(() => _placing = true);
      try {
        await repos.order.saveEdit(
          orderId,
          notes: _notes,
          transport: _preferredTransport,
          expectedDeliveryDate:
              _expectedDate == null ? null : toApiDate(_expectedDate!),
        );
        _editCommitted = true;
        OrderDraftSession.clear();
        if (!mounted) return;
        AppToast.success(context, 'Order updated successfully');
        _leaveToStatus();
      } on ApiException catch (e) {
        if (!mounted) return;
        final items = _outOfStockItems(e.data);
        if (items.isNotEmpty) {
          await _showOutOfStock(items);
        } else {
          AppToast.error(context, e.message);
        }
        if (mounted) setState(() => _placing = false);
      } catch (e) {
        if (!mounted) return;
        AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
        setState(() => _placing = false);
      }
      return;
    }
    await _saveFields();
    OrderDraftSession.clear();
    if (!mounted) return;
    _leaveToStatus();
  }

  void _leaveToStatus() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin/order/status/${widget.editOrderId}');
    }
  }

  Future<void> _footerAction() => _isEdit ? _finishEdit() : _placeOrder();

  Future<void> _placeOrder() async {
    final orderId = OrderDraftSession.orderId;
    if (orderId == null || _order == null) return;
    final duplicates = computeDuplicateGroups(_order!.items);
    if (duplicates.isNotEmpty) {
      final proceed = await _confirmMerge(duplicates);
      if (proceed != true) return;
      await _mergeThenPlace(orderId, duplicates);
      return;
    }
    await _place(orderId);
  }

  Future<void> _place(int orderId) async {
    setState(() => _placing = true);
    try {
      _saveDebounce?.cancel();
      await _saveFields();
      await repos.order.place(
        orderId,
        expectedDeliveryDate:
            _expectedDate == null ? null : toApiDate(_expectedDate!),
        preferredTransport: _preferredTransport,
        notes: _notes.isEmpty ? null : _notes,
      );
      OrderDraftSession.clear();
      if (!mounted) return;
      AppToast.success(context, 'Order placed successfully!');
      final router = GoRouter.of(context);
      router.go('/admin');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        router.push('/admin/order/status/$orderId');
      });
    } on ApiException catch (e) {
      final items = _outOfStockItems(e.data);
      if (items.isNotEmpty) {
        await _showOutOfStock(items);
      } else if (mounted) {
        AppToast.error(context, e.message);
      }
      if (mounted) setState(() => _placing = false);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
        setState(() => _placing = false);
      }
    }
  }

  Future<void> _mergeThenPlace(
      int orderId, List<OrderMergeGroup> groups) async {
    setState(() => _placing = true);
    try {
      for (final group in groups) {
        await repos.order.updateItem(group.items.first.id, {'quantity': group.total});
        for (var i = 1; i < group.items.length; i++) {
          await repos.order.deleteItem(orderId, group.items[i].id);
        }
      }
      final refreshed = await repos.order.getOne(orderId);
      if (mounted) setState(() => _order = refreshed);
      await _place(orderId);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
        setState(() => _placing = false);
      }
    }
  }

  Future<void> _deleteItem(OrderItem item) async {
    final orderId = OrderDraftSession.orderId;
    if (orderId == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Remove item?',
      message: 'This action cannot be undone.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    try {
      await repos.order.deleteItem(orderId, item.id);
      await _reloadOrder();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _reloadOrder() async {
    final orderId = _orderId;
    if (orderId == null) return;
    final order = await repos.order.getOne(orderId);
    if (mounted) setState(() => _order = order);
  }

  void _addItem() {
    _syncDraftSession();
    context.push('/admin/order/new/$_effectiveCustomerId/scan');
  }

  void _editItem(OrderItem item) {
    final qr = item.item?.variants
        .where((v) => v.id == item.variant)
        .map((v) => v.qrCode)
        .firstWhere((q) => q != null && q.isNotEmpty, orElse: () => null);
    if (qr == null) {
      AppToast.error(context, 'This item has no QR code to edit.');
      return;
    }
    _syncDraftSession();
    context.push(
        '/admin/order/new/$_effectiveCustomerId/item/${Uri.encodeComponent(qr)}');
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() => _expectedDate = picked);
      _scheduleSave();
    }
  }

Future<void> _handleLeave() async {
    // An open edit transaction must be released on the server, otherwise the
    // order would stay stuck in EDITING.
    if (_isEditingSession && !_editCommitted) {
      _saveDebounce?.cancel();
      try {
        await repos.order.cancelEdit(_orderId!);
      } catch (_) {}
      OrderDraftSession.clear();
      if (!mounted) return;
      _leaveToStatus();
      return;
    }
    // Editing an existing order auto-saves every change, so leave directly.
    if (_isEdit) {
      OrderDraftSession.clear();
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/admin');
      }
      return;
    }
    final items = _order?.items ?? const <OrderItem>[];
    if (items.isNotEmpty) {
      final leave = await confirmDialog(
        context,
        title: 'Leave Order?',
        message: 'The draft stays saved for 24 hours.',
        confirmLabel: 'Leave',
        destructive: true,
      );
      if (leave != true) return;
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin');
    }
  }

  Widget _guard(Widget child) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _handleLeave();
        },
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _guard(const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: PageLoading(label: 'Loading order...')),
      ));
    }
    if (_loadError != null) return _guard(_errorScaffold(_loadError!));

    final order = _order;
    final customer = _customer;
    if (order == null || customer == null) {
      return _guard(_errorScaffold(const _LoadError.error('Order unavailable.')));
    }

    final items = order.items;
    final totalSets = items.fold<int>(0, (sum, i) => sum + i.quantity);
    final totalPieces = items.fold<int>(
        0, (sum, i) => sum + i.quantity * (i.pieceCount ?? 1));
    final totalMoney = items.fold<num>(
        0,
        (sum, i) =>
            sum +
            (num.tryParse(i.displayPrice) ?? 0) *
                i.quantity *
                (i.pieceCount ?? 1));

return _guard(
      Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Column(
          children: [
            _header(items.length),
            OfflineBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  _customerCard(customer),
                  const SizedBox(height: 16),
                  _itemsSection(items),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _totalsCard(totalSets, totalPieces, totalMoney),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorScaffold(_LoadError error) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFBFA),
        elevation: 0,
leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/admin'),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF9CA3AF)),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                error.notfound
                    ? Icons.warning_amber_outlined
                    : Icons.error_outline,
                size: 44,
                color: error.notfound
                    ? const Color(0xFFD97706)
                    : AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                error.notfound ? 'Order unavailable' : 'Something went wrong',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827)),
              ),
              const SizedBox(height: 6),
Text(
                error.notfound
                    ? (_isEdit
                        ? 'This order no longer exists or has been deleted.'
                        : 'This order draft has expired or was removed. You can start a new order for this customer.')
                    : (error.message ?? 'Something went wrong'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 20),
              if (error.notfound)
                StockFlowButton(
                  label: _isEdit ? 'Back' : 'Start new order',
                  onPressed: () {
                    OrderDraftSession.clear();
                    if (_isEdit) {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      context.go('/admin');
                      return;
                    }
                    context.pushReplacement(
                        '/admin/order/new?customer=$_effectiveCustomerId');
                  },
                )
              else
                StockFlowButton(
                  label: 'Retry',
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _loadError = null;
                    });
                    _load();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

Widget _header(int itemCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 14, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _handleLeave,
                icon: const Icon(Icons.arrow_back, color: Color(0xFF9CA3AF)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isEdit ? 'Edit Order' : 'Order Details',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827))),
                    Text(
                        _isEdit
                            ? 'EDIT ITEMS'
                            : 'STEP 2 $kEmDash ADD ITEMS',
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                            color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              if (itemCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Text('$itemCount',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ),
            ],
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Order for ${_customer?.name ?? kEmDash}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151))),
                ),
                Text('Agent: ${_customer?.agentName ?? kEmDash}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerCard(Customer customer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_outline,
                    size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CUSTOMER',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                            color: Color(0xFF9CA3AF))),
                    Text(customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827))),
                  ],
                ),
              ),
            ],
          ),
          if ((customer.address ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(customer.address!,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280))),
            ),
          const Divider(height: 28, color: Color(0xFFF3F4F6)),
          const Text('Delivery Options',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827))),
          const SizedBox(height: 12),
          _dateField(),
          const SizedBox(height: 12),
          _transportField(),
          const SizedBox(height: 12),
          const Text('NOTES',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                  color: Color(0xFF9CA3AF))),
          const SizedBox(height: 4),
          TextField(
            controller: _notesController,
            maxLines: 3,
            onChanged: (v) {
              _notes = v;
              _scheduleSave();
            },
            decoration: _fieldDecoration('Any special instructions...'),
          ),
        ],
      ),
    );
  }

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('EXPECTED DELIVERY DATE',
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: Color(0xFF9CA3AF))),
        const SizedBox(height: 4),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _expectedDate == null
                        ? 'Whenever'
                        : toApiDate(_expectedDate!),
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF374151)),
                  ),
                ),
                if (_expectedDate != null)
                  InkWell(
                    onTap: () {
                      setState(() => _expectedDate = null);
                      _scheduleSave();
                    },
                    child: const Icon(Icons.close,
                        size: 16, color: Color(0xFF9CA3AF)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _transportField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PREFERRED TRANSPORT',
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: Color(0xFF9CA3AF))),
        const SizedBox(height: 4),
        DropdownButtonFormField<int?>(
          value: _transports.any((t) => t.id == _preferredTransport)
              ? _preferredTransport
              : null,
          isExpanded: true,
          decoration: _fieldDecoration('None'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('None')),
            for (final t in _transports)
              DropdownMenuItem<int?>(value: t.id, child: Text(t.name)),
          ],
          onChanged: (v) {
            setState(() => _preferredTransport = v);
            _scheduleSave();
          },
        ),
      ],
    );
  }

  Widget _itemsSection(List<OrderItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Order Items',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827))),
                  Text(
                    items.isEmpty
                        ? 'No items yet'
                        : '${items.length} item${items.length == 1 ? '' : 's'} added',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            StockFlowButton(
              label: 'Add Item',
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              onPressed: _addItem,
              expand: false,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _addItem,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFE5E7EB), style: BorderStyle.solid),
              ),
              child: Column(
                children: const [
                  Icon(Icons.shopping_bag_outlined,
                      size: 30, color: Color(0xFFD1D5DB)),
                  SizedBox(height: 8),
                  Text('No items added yet',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280))),
                  SizedBox(height: 2),
                  Text('Tap to scan items',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                for (final item in items)
                  _OrderItemRow(
                    item: item,
                    onEdit: () => _editItem(item),
                    onDelete: () => _deleteItem(item),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _totalsCard(int sets, int pieces, num money) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _totalStat('Total Sets', '$sets'),
              _totalStat('Total Pieces', '$pieces'),
              _totalStat('Total Value', formatInrInt(money)),
            ],
          ),
          const SizedBox(height: 16),
StockFlowButton(
            label: _isEdit ? 'Save Order' : 'Place Order',
            loading: _placing,
            icon: const Icon(Icons.check_circle_outline,
                size: 18, color: Colors.white),
            onPressed: _placing ? null : _footerAction,
          ),
        ],
      ),
    );
  }

  Widget _totalStat(String label, String value) {
    return Column(
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: Color(0xFF9CA3AF))),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827))),
      ],
    );
  }

  Future<bool?> _confirmMerge(List<OrderMergeGroup> groups) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicate Items',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Some items share the same colour and size range. They'll be combined into one entry with the total quantity.",
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            for (final group in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    '${group.itemName} $kMiddleDot ${group.sizeGroup} $kArrow ${group.total} sets',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E)),
                  ),
                ),
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
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOutOfStock(List<OutOfStockItem> items) {
    final grouped = <int, OutOfStockItem>{};
    for (final item in items) {
      final existing = grouped[item.orderItemId];
      grouped[item.orderItemId] = existing == null
          ? item
          : OutOfStockItem(
              itemName: item.itemName,
              sizeGroup: item.sizeGroup,
              size: item.size,
              requiredQty: existing.requiredQty,
              available: existing.available < item.available
                  ? existing.available
                  : item.available,
              orderItemId: item.orderItemId,
            );
    }
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Out of Stock',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Some items are unavailable. Stock may have been taken by another agent.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              for (final item in grouped.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.itemName,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827))),
                        Text(item.sizeGroup,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF6B7280))),
                        Text(
                          'Requested: ${item.requiredQty}   Available: ${item.available}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
        ),
      );
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final OrderItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final pieceCount = item.pieceCount ?? 1;
    final price = num.tryParse(item.displayPrice) ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF9FAFB))),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 46,
              height: 46,
              child: AppImage(item.toVariantImage(), iconSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayNameWithColor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827)),
                ),
                Text(
                  'Size: ${item.displaySizeGroup ?? kEmDash}',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity} Set${item.quantity == 1 ? '' : 's'} $kMultiply $pieceCount pcs = ${item.quantity * pieceCount} pcs',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF4B5563)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatInrInt(price * item.quantity * pieceCount),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827))),
              Row(
                children: [
                  IconButton(
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined,
                        size: 16, color: AppColors.primary),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Color(0xFFEF4444)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
