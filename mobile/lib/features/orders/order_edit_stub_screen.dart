import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

/// Lightweight parity for the separate `/admin/order/status/:id/edit` route.
/// Mirrors `app/(admin)/admin/order/status/[id]/edit/page.tsx` - shows the
/// ordered items with a Save header action; item-level edits live on the
/// status screen.
class OrderEditStubScreen extends StatefulWidget {
  const OrderEditStubScreen({super.key, required this.orderId});
  final int orderId;

  @override
  State<OrderEditStubScreen> createState() => _OrderEditStubScreenState();
}

class _OrderEditStubScreenState extends State<OrderEditStubScreen> {
  Order? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await repos.order.getOne(widget.orderId);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/admin/order/status/${widget.orderId}'),
                    icon: const Icon(Icons.chevron_left,
                        size: 20, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(width: 4),
                  const Text('Back',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111827))),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      AppToast.success(context, 'Order updated');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Text('Save',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(width: 6),
                          Icon(Icons.save_outlined,
                              size: 15, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Ordered Items',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827))),
            ),
            Expanded(
              child: _loading
                  ? const PageLoading()
                  : _error != null
                      ? EmptyState(
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
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            for (final item in _order?.items ?? const <OrderItem>[])
                              _StubRow(item: item),
                          ],
                        ),
            ),
],
        ),
      ),
    );
  }
}

class _StubRow extends StatelessWidget {
  const _StubRow({required this.item});
  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final pieces = (item.pieceCount ?? 1) * item.quantity;
    final price = num.tryParse(item.itemPrice ?? '') ?? 0;
    final image = item.toVariantImage();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: (image?.isNotEmpty ?? false)
                ? () => showImagePreview(context, image)
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 44, height: 44, child: AppImage(image)),
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
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text('Size: ${item.sizeGroup ?? 'N/A'}',
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9CA3AF))),
                Text('${item.quantity} Set(s) = $pieces pcs',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF4B5563))),
              ],
            ),
          ),
          Text(
            formatInrInt(price * item.quantity * (item.pieceCount ?? 1)),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}