import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shared auth-screen widgets mirroring `components/pages/auth/*`.

class AuthBranding extends StatelessWidget {
  const AuthBranding({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 4)),
            ],
          ),
          child: const Icon(Icons.inventory_2, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 12),
        const Text(
          'XL Apparals',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.heading),
        ),
        const SizedBox(height: 2),
        const Text(
          'ORDER MANAGEMENT',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.shake, required this.children});
  final bool shake;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
      offset: shake ? const Offset(0.015, 0) : Offset.zero,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 384),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 34, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...children.expand(
              (w) => [w, const SizedBox(height: 24)],
            ),
          ].toList(),
        ),
      ),
    );
  }
}

class AuthAlert extends StatelessWidget {
  const AuthAlert({super.key, required this.message, this.sub, this.warn = false});
  final String message;
  final String? sub;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    final bg = warn ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2);
    final border = warn ? const Color(0xFFFDE68A) : const Color(0xFFFECACA);
    final fg = warn ? const Color(0xFF92400E) : const Color(0xFFB91C1C);
    final iconColor = warn ? const Color(0xFFF59E0B) : const Color(0xFFF87171);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warn ? Icons.error_outline : Icons.error_outline, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.isNotEmpty)
                  Text(message,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: fg,
                        height: 1.3,
                      )),
                if (sub != null && sub!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub!, style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.85))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.label,
    this.controller,
    this.obscured = true,
    this.onChanged,
    this.error,
    this.autofocus = false,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final bool obscured;
  final ValueChanged<String>? onChanged;
  final String? error;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: !_show,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
          onSubmitted: (_) => widget.onSubmitted?.call(),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            errorText: widget.error?.isEmpty == false ? widget.error : null,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _show = !_show),
              icon: Icon(
                _show ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.loading,
    required this.label,
    required this.loadingLabel,
    this.icon,
    this.onPressed,
  });

  final bool loading;
  final String label;
  final String loadingLabel;
  final Widget? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(loadingLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
            ] else ...[
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }
}