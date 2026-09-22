import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/cache/app_cache.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/status_maps.dart';
import '../core/utils/text_symbols.dart';
import '../providers.dart';
import '../models/models.dart';

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = statusBadgeColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        status == OrderStatus.unknown ? kEmDash : status.label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: fg,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pulsing unread dot
// ---------------------------------------------------------------------------

/// A solid dot with a soft ring that expands (1.0 -> 2.2) while fading
/// (0.5 -> 0) every ~1.4s. Used to mark unread order cards.
///
/// Only unread cards build this widget. Pass a shared [controller] from the
/// list owner so a long list uses one ticker instead of one per card; when
/// omitted the dot owns (and disposes) its own controller. Honours
/// `MediaQuery.disableAnimations` by rendering the static dot. The per-frame
/// rebuild is scoped to the dot (AnimatedBuilder) and wrapped in a
/// [RepaintBoundary].
class PulsingDot extends StatefulWidget {
  const PulsingDot({
    super.key,
    this.size = 11,
    this.color = AppColors.unread,
    this.borderColor = Colors.white,
    this.controller,
  });

  final double size;
  final Color color;
  final Color borderColor;

  /// Optional externally-owned controller (not disposed by this widget).
  final AnimationController? controller;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  static const Duration _period = Duration(milliseconds: 1400);
  AnimationController? _owned;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncOwned();
  }

  @override
  void didUpdateWidget(PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _syncOwned();
  }

  /// Creates/starts the owned controller only when needed: no shared
  /// controller was supplied and the platform has not disabled animations.
  void _syncOwned() {
    if (widget.controller != null) {
      _owned?.dispose();
      _owned = null;
      return;
    }
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disabled) {
      _owned?.dispose();
      _owned = null;
    } else {
      _owned ??= AnimationController(vsync: this, duration: _period)..repeat();
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.of(context).disableAnimations;
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        border: Border.all(color: widget.borderColor, width: 2),
      ),
    );

    final controller = widget.controller ?? _owned;
    if (disabled || controller == null) {
      return RepaintBoundary(child: dot);
    }

    final maxRing = widget.size * 2.2;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final t = Curves.easeOut.transform(controller.value);
                final ring = widget.size + (maxRing - widget.size) * t;
                return Opacity(
                  opacity: (0.5 * (1 - t)).clamp(0.0, 1.0),
                  child: Container(
                    width: ring,
                    height: ring,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
            dot,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons / loading / empty
// ---------------------------------------------------------------------------

class StockFlowButton extends StatelessWidget {
  const StockFlowButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.disabled = false,
    this.enabled,
    this.icon,
    this.destructive = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool disabled;
  final bool? enabled;
  final Widget? icon;
  final bool destructive;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final isDisabled =
        enabled == false || disabled || loading || onPressed == null;
    final content = loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Text(label),
            ],
          );
    if (destructive) {
      return SizedBox(
        width: expand ? double.infinity : null,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: isDisabled ? null : onPressed,
          child: content,
        ),
      );
    }
    return SizedBox(
      width: expand ? double.infinity : null,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: isDisabled ? null : onPressed,
        child: content,
      ),
    );
  }
}

/// A text field that owns its [TextEditingController] internally so the
/// controller is never recreated on rebuild. Creating a fresh controller in
/// `build()` (as a StatelessWidget body does) swaps the controller on every
/// keystroke: the selection is lost and typed text scrambles/disappears.
class StockFlowTextField extends StatefulWidget {
  const StockFlowTextField({
    super.key,
    this.label,
    this.hint,
    this.initialText = '',
    this.onChanged,
    this.prefixText,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLines = 1,
    this.minLines,
    this.inputFormatters,
    this.textAlign,
    this.enabled = true,
    this.fillColor = const Color(0xFFF9FAFB),
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.borderRadius = 12,
  });

  final String? label;
  final String? hint;
  final String initialText;
  final ValueChanged<String>? onChanged;
  final String? prefixText;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final int? minLines;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign? textAlign;
  final bool enabled;
  final Color fillColor;
  final EdgeInsetsGeometry contentPadding;
  final double borderRadius;

  @override
  State<StockFlowTextField> createState() => _StockFlowTextFieldState();
}

class _StockFlowTextFieldState extends State<StockFlowTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(StockFlowTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Let external value changes flow in, but never clobber text the user is
    // actively typing (focused) or that already matches the controller.
    if (!_focusNode.hasFocus &&
        widget.initialText != oldWidget.initialText &&
        widget.initialText != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initialText,
        selection: TextSelection.collapsed(offset: widget.initialText.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      inputFormatters: widget.inputFormatters,
      textAlign: widget.textAlign ?? TextAlign.start,
      enabled: widget.enabled,
      focusNode: _focusNode,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        prefixText: widget.prefixText,
        prefixStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280)),
        errorText: widget.errorText,
        errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFF87171)),
        filled: true,
        fillColor: widget.fillColor,
        contentPadding: widget.contentPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide:
              BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: const BorderSide(color: Color(0xFFF87171)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: const BorderSide(color: Color(0xFFF87171)),
        ),
      ),
    );
    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label!,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563))),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

class PageLoading extends StatelessWidget {
  const PageLoading({super.key, this.label});
  final String? label;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2.5),
            if (label != null) ...[
              const SizedBox(height: 12),
              Text(label!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle,
      this.action});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Images & avatars
// ---------------------------------------------------------------------------

/// Decode dimension (device pixels) for a box of [boxWidth] x [boxHeight].
///
/// `ResizeImage` uses [ResizeImagePolicy.exact] by default: passing BOTH width
/// and height decodes the bitmap to that exact size (equivalent to
/// `BoxFit.fill`), which stretches the image before `BoxFit.cover` ever runs.
/// We therefore hand `ResizeImage` a single dimension so the aspect ratio is
/// preserved, choosing the larger box side so `BoxFit.cover` still has enough
/// pixels to crop from. Returns a sane fallback for unbounded constraints.
int appImageDecodeSide(
  double boxWidth,
  double boxHeight,
  double dpr, {
  double fallback = 22,
}) {
  final w = boxWidth.isFinite && boxWidth >= 8 ? boxWidth : fallback;
  final h = boxHeight.isFinite && boxHeight >= 8 ? boxHeight : fallback;
  final side = w > h ? w : h;
  final pixels = (side * dpr).round();
  return pixels < 1 ? 1 : pixels;
}

class AppImage extends StatelessWidget {
  const AppImage(this.url,
      {super.key,
      this.fit = BoxFit.cover,
      this.iconSize = 22,
      this.previewEnabled = false});
  final String? url;
  final BoxFit fit;
  final double iconSize;

  /// When true, tapping the image opens the full-screen preview
  /// ([showImagePreview]) using the same resolved URL, so the cached bytes
  /// are reused. The tap target is the image only (wrapped with
  /// `HitTestBehavior.opaque`); empty images stay as non-tappable placeholders.
  final bool previewEnabled;

  @override
  Widget build(BuildContext context) {
    final resolved = url == null || url!.isEmpty ? '' : AppConfig.resolveImageUrl(url);
    if (resolved.isEmpty) {
      return _placeholder();
    }
    // Decode at the displayed on-screen size instead of the full file
    // resolution (server images are up to 1024px). This slashes memory and
    // decode cost for small list thumbnails.
    final image = LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        // A single decode dimension keeps the aspect ratio intact; see
        // [appImageDecodeSide].
        final decodeSide = appImageDecodeSide(
          constraints.maxWidth,
          constraints.maxHeight,
          dpr,
          fallback: iconSize,
        );
        return CachedNetworkImage(
          imageUrl: resolved,
          fit: fit,
          cacheManager: AppCache.imageCacheManager,
          imageBuilder: (context, imageProvider) => Image(
            image: ResizeImage.resizeIfNeeded(decodeSide, null, imageProvider),
            fit: fit,
          ),
          placeholder: (_, __) =>
              Container(color: AppColors.grayBg, child: _placeholder()),
          errorWidget: (_, __, ___) => _placeholder(),
        );
      },
    );
    if (!previewEnabled) return image;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showImagePreview(context, url),
      child: image,
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.grayBg,
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, size: iconSize, color: AppColors.textMuted),
      );
}

// ---------------------------------------------------------------------------
// Full-screen image preview
// ---------------------------------------------------------------------------

/// Opens a full-screen preview of the image referenced by [path].
///
/// Uses the same resolved URL as [AppImage], so the already-cached
/// `CachedNetworkImage` bytes are reused (no extra download). Does nothing
/// when there is no actual image. Closes via Android back, the close button,
/// or by tapping anywhere.
Future<void> showImagePreview(BuildContext context, String? path) async {
  final resolved = path == null || path.isEmpty ? '' : AppConfig.resolveImageUrl(path);
  if (resolved.isEmpty) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close image preview',
    barrierColor: Colors.black.withValues(alpha: 0.88),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (ctx, _, __) => _ImagePreview(resolved: resolved),
  );
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.resolved});
  final String resolved;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: resolved,
                  fit: BoxFit.contain,
                  cacheManager: AppCache.imageCacheManager,
                  placeholder: (_, __) => const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white70),
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 44,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const List<Color> _avatarPalette = [
  Color(0xFFE65100),
  Color(0xFF6A1B9A),
  Color(0xFF00695C),
  Color(0xFF283593),
  Color(0xFFAD1457),
  Color(0xFF4E342E),
];

Color _colorFromId(int id) => _avatarPalette[id % _avatarPalette.length];

class StockflowAvatar extends StatelessWidget {
  const StockflowAvatar({super.key, required this.id, required this.name, this.radius = 18});
  final int id;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: _colorFromId(id),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Offline banner
// ---------------------------------------------------------------------------

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider).valueOrNull ?? true;
    if (online) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.grayFg,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, size: 14, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Offline $kEmDash showing cached data',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Headers
// ---------------------------------------------------------------------------

class BackHeader extends StatelessWidget {
  const BackHeader({super.key, this.title, this.trailing});
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.heading),
        ),
        if (title != null) ...[
          Expanded(
            child: Text(
              title!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ] else ...[
          const Expanded(child: SizedBox()),
        ],
        trailing ?? const SizedBox(width: 44),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.heading,
          ),
        ),
      );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 13, color: AppColors.heading),
              ),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Toasts (sonner-style, top-right)
// ---------------------------------------------------------------------------

class AppToast {
  static void show(BuildContext context, String message,
      {String? description, bool isError = false}) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastOverlay(
        message: message,
        description: description,
        isError: isError,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  static void success(BuildContext context, String message) => show(context, message);
  static void error(BuildContext context, String message) => show(context, message, isError: true);
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.message,
    this.description,
    required this.isError,
    required this.onDone,
  });
  final String message;
  final String? description;
  final bool isError;
  final VoidCallback onDone;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final Animation<Offset> _slide = Tween(begin: const Offset(1, 0), end: Offset.zero)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        _controller.reverse().whenComplete(widget.onDone);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 54,
      right: 14,
      child: SlideTransition(
        position: _slide,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                widget.isError ? Icons.error_outline : Icons.check_circle_outline,
                size: 17,
                color: widget.isError ? const Color(0xFFF87171) : const Color(0xFF4ADE80),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.message,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    if (widget.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.description!,
                        style: const TextStyle(
                            color: Color(0xFFB4B4B4), fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

class PinDialog extends StatelessWidget {
  const PinDialog({super.key, required this.title, this.message});
  final String title;
  final String? message;

  static Future<String?> show(BuildContext context,
      {String title = 'Enter PIN', String? message}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message != null) ...[
              Text(message, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'PIN', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: message == null ? null : Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                confirmLabel,
                style: TextStyle(
                  color: destructive ? const Color(0xFFDC2626) : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ) ??
      false;
}

// ---------------------------------------------------------------------------
// Delete-with-transfer dialog — mirrors `DeleteWithTransferDialog.tsx`.
// Agents may transfer customers to another agent (`transferable_agents`);
// customers always deactivate. PIN always required (mobile admin = non-root).
// ---------------------------------------------------------------------------

class DeleteWithTransferDialog extends StatefulWidget {
  const DeleteWithTransferDialog({
    super.key,
    required this.entityType,
    required this.entityName,
    required this.fetchDeleteInfo,
    required this.onDelete,
  });

  /// 'agent' or 'customer'.
  final String entityType;
  final String entityName;
  final Future<Map<String, dynamic>> Function() fetchDeleteInfo;
  final Future<void> Function({required String pin, required String action, int? transferToId}) onDelete;

  @override
  State<DeleteWithTransferDialog> createState() => _DeleteWithTransferDialogState();
}

class _DeleteWithTransferDialogState extends State<DeleteWithTransferDialog> {
  bool _fetching = true;
  bool _loading = false;
  Map<String, dynamic> _info = const {};
  List<({int id, String name})> _transfers = const [];
  String _action = 'deactivate';
  int? _transferToId;
  final _pinController = TextEditingController();
  String _error = '';

  bool get _isAgent => widget.entityType == 'agent';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await widget.fetchDeleteInfo();
      if (!mounted) return;
      final list = (info['transferable_agents'] as List?) ?? const [];
      setState(() {
        _info = info;
        _transfers = list
            .map((e) {
              final m = (e as Map).cast<String, dynamic>();
              return (id: m['id'] as int? ?? 0, name: (m['name'] as String?) ?? '');
            })
            .toList();
        _fetching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fetching = false;
        _error = 'Failed to load delete info';
      });
    }
  }

  String _summary(Map<String, dynamic> c) {
    if (_isAgent) {
      return 'This agent has ${c['customers_count'] ?? 0} customers and ${c['orders_count'] ?? 0} orders.';
    }
    return 'This customer has ${c['orders_count'] ?? 0} orders.';
  }

  Future<void> _confirm() async {
    final pin = _pinController.text;
    if (pin.length < 6) {
      setState(() => _error = 'Please enter all 6 digits.');
      return;
    }
    if (_action == 'transfer' && _transferToId == null) {
      setState(() => _error = 'Please select a target to transfer to.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await widget.onDelete(
        pin: pin,
        action: _action,
        transferToId: _transferToId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
        _pinController.clear();
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counts = _info;
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isAgent ? 'Delete Agent' : 'Delete Customer',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: _fetching
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          : _loading
              ? const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.entityName} $kEmDash ${_summary(counts)}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 16),
                    if (_isAgent) ...[
                      _RadioTile(
                        value: 'transfer',
                        group: _action,
                        enabled: _transfers.isNotEmpty,
                        label: 'Transfer customers to another agent',
                        onChanged: (v) => setState(() => _action = v),
                      ),
                      if (_action == 'transfer')
                        Padding(
                          padding: const EdgeInsets.only(left: 24, top: 8, bottom: 8),
                          child: DropdownButtonFormField<int>(
                            value: _transferToId,
                            hint: Text('Select agent...',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.textMuted)),
                            items: [
                              for (final t in _transfers)
                                DropdownMenuItem(value: t.id, child: Text(t.name)),
                            ],
                            onChanged: (v) => setState(() => _transferToId = v),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                            ),
                          ),
                        ),
                      _RadioTile(
                        value: 'deactivate',
                        group: _action,
                        label: 'Keep historical references (Deactivate agent)',
                        onChanged: (v) => setState(() => _action = v),
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Keep historical references (Deactivate customer). All historical data will be preserved.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ),
                    const Divider(),
                    const Text(
                      'Enter your 6-digit PIN to confirm',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: false,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 12),
                      decoration: const InputDecoration(
                        labelText: 'PIN',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (_error.startsWith('Please enter') ||
                            _error.startsWith('Please select')) {
                          setState(() => _error = '');
                        }
                      },
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white),
          onPressed: _loading || _fetching ? null : _confirm,
          child: Text(_action == 'transfer' ? 'Transfer & Delete' : 'Deactivate'),
        ),
      ],
    );
  }
}

class _RadioTile extends StatelessWidget {
  const _RadioTile({
    required this.value,
    required this.group,
    required this.label,
    required this.onChanged,
    this.enabled = true,
  });
  final String value;
  final String group;
  final String label;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: enabled ? () => onChanged(value) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Radio<String>(
                value: value,
                groupValue: group,
                onChanged: enabled ? (v) => onChanged(value) : null,
                activeColor: AppColors.primary,
              ),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: enabled ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model helpers
// ---------------------------------------------------------------------------

double orderItemTotalPieces(OrderItem oi) {
  final pc = oi.pieceCount;
  return pc != null ? (pc * oi.quantity).toDouble() : double.parse(oi.quantity.toString());
}