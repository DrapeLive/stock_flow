import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories.dart';
import '../../shared/widgets.dart';
import 'order_flow_utils.dart';

/// Step 3 â€” scan a variant QR. Mirrors `components/pages/ScannerPage.tsx`.
class OrderCreateScannerScreen extends ConsumerStatefulWidget {
  const OrderCreateScannerScreen({super.key, required this.customerId});

  final int customerId;

  @override
  ConsumerState<OrderCreateScannerScreen> createState() =>
      _OrderCreateScannerScreenState();
}

class _OrderCreateScannerScreenState
    extends ConsumerState<OrderCreateScannerScreen> {
  bool _busy = false;

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    final barcode =
        capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final raw = barcode?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _validate(raw);
  }

  Future<void> _validate(String qr) async {
    setState(() => _busy = true);
    try {
      final result = await repos.item
          .checkOutOfStock(qr, orderId: OrderDraftSession.orderId);
      if (!mounted) return;
      if (result.outOfStock) {
        await _showOutOfStockDialog();
        if (mounted) setState(() => _busy = false);
        return;
      }
      context.pushReplacement(
          '/admin/order/new/${widget.customerId}/item/${Uri.encodeComponent(qr)}');
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(
          context, e.toString().replaceFirst('Exception: ', ''));
      setState(() => _busy = false);
    }
  }

  Future<void> _showOutOfStockDialog() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.archive_outlined,
                  color: Color(0xFFDC2626), size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Out of Stock',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: const Text(
          'This item is out of stock, you can add other items though.',
          style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Scan another QR'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _backToOrder();
            },
            child: const Text('Back to Orders'),
          ),
        ],
      ),
    );
  }

  void _backToOrder() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin/order/new/${widget.customerId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _backToOrder();
      },
child: Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          body: Column(
            children: [
              _header(),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MobileScanner(onDetect: _onDetect),
                              IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 4,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.qr_code,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              _busy ? 'CHECKING...' : 'AWAITING SCAN',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                  color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Align QR Code',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937))),
                      const SizedBox(height: 6),
                      const Text(
                        "Position the item's QR code within the frame to add it to the order",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 14, 16, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: _backToOrder,
            icon: const Icon(Icons.arrow_back, color: Color(0xFF9CA3AF)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Scan Item',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827))),
              Text('STEP 3: QR SCANNER',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: Color(0xFF9CA3AF))),
            ],
          ),
        ],
      ),
    );
  }
}
