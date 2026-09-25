import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../providers.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// Admin bottom navigation — mirrors `components/ui/AdminNavBar.tsx`
// (Settings tab omitted: superuser-only).
// ---------------------------------------------------------------------------

class AdminNavBar extends StatelessWidget {
  const AdminNavBar({super.key, required this.activePath});
  final String activePath;

  static const _tabs = [
    (label: 'Users', path: '/admin/users', icon: Icons.people_outline, iconActive: Icons.people),
    (label: 'Orders', path: '/admin', icon: Icons.local_shipping_outlined, iconActive: Icons.local_shipping),
    (label: 'Stats', path: '/admin/analytics', icon: Icons.bar_chart, iconActive: Icons.bar_chart),
    (label: 'Stock', path: '/admin/items', icon: Icons.inventory_2_outlined, iconActive: Icons.inventory_2),
  ];

  bool _isActive(String path) {
    if (path == '/admin') return activePath == '/admin';
    return activePath.startsWith(path);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0x11000000)],
        ),
      ),
      padding: EdgeInsets.only(
        bottom: 10 + MediaQuery.of(context).padding.bottom,
      ),
      margin: const EdgeInsets.only(top: 4),
child: Container(
          height: 62,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white70),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          child: Row(
            children: [
              for (final tab in _tabs)
                Expanded(
                  child: InkWell(
                    onTap: () => context.go(tab.path),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _isActive(tab.path) ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isActive(tab.path) ? tab.iconActive : tab.icon,
                            size: 20,
                            color: _isActive(tab.path) ? Colors.white : AppColors.textMuted,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tab.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: _isActive(tab.path) ? Colors.white : AppColors.textMuted,
                            ),
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
}

// ---------------------------------------------------------------------------
// Top-right profile avatar — opened via push from the shared header bar.
// ---------------------------------------------------------------------------

class AdminProfileButton extends ConsumerWidget {
  const AdminProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider.select((s) => s?.user));
    final name = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.username?.isNotEmpty ?? false)
            ? user!.username!
            : 'A';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.push('/admin/profile'),
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: StockflowAvatar(id: user?.id ?? 0, name: name, radius: 16.5),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared admin page scaffold
// ---------------------------------------------------------------------------

class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.body,
    this.activePath = '',
    this.showNav = true,
    this.title,
    this.titleTrailing,
  });

  final Widget body;
  final String activePath;
  final bool showNav;
  final String? title;
  final Widget? titleTrailing;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: !showNav,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AdminHeader(title: title, titleTrailing: titleTrailing),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: body,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar:
            showNav ? AdminNavBar(activePath: activePath) : null,
      ),
    );
  }
}

/// Shared top bar: optional screen title (left) + profile avatar (right).
/// Sits inside [SafeArea], so content always clears the status bar and the
/// avatar aligns with the screen title across devices.
class _AdminHeader extends StatelessWidget {
  const _AdminHeader({this.title, this.titleTrailing});

  final String? title;
  final Widget? titleTrailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: title == null
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      Flexible(
                        child: Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (titleTrailing != null) ...[
                        const SizedBox(width: 8),
                        titleTrailing!,
                      ],
                    ],
                  ),
          ),
          const AdminProfileButton(),
        ],
      ),
    );
  }
}