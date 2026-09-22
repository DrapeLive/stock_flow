import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/text_symbols.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../providers.dart';
import '../../shared/widgets.dart';
import 'archived_item_card.dart';

/// Mirrors `components/pages/profile/ProfilePage.tsx` (admin context).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _tab = 'profile';

  AuthUser? _profile;

  List<Item> _archivedItems = const [];
  List<Order> _archivedOrders = const [];
  bool _archivesLoading = false;
  int? _expandedItem;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

Future<void> _loadProfile() async {
    // Single source of truth: refreshProfile fetches, persists and publishes
    // the fresh profile. The screen keeps rendering the (cached) session user
    // in the meantime, so details are never blank.
    final profile = await ref.read(sessionProvider.notifier).refreshProfile();
    if (mounted && profile != null) setState(() => _profile = profile);
  }

  @override
  void didUpdateWidget(covariant ProfileScreen old) {
    super.didUpdateWidget(old);
    if (_tab == 'archives' && _archivedItems.isEmpty && !_archivesLoading) {
      _loadArchives();
    }
  }

  Future<void> _loadArchives() async {
    setState(() => _archivesLoading = true);
    try {
      final items = await repos.item.archived();
      final orders = (await repos.order.archived()).results;
      if (!mounted) return;
      setState(() {
        _archivedItems = items;
        _archivedOrders = orders;
        _archivesLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _archivesLoading = false);
        AppToast.error(context, 'Failed to load archives');
      }
    }
  }

  void _switchTab(String next) {
    if (next == _tab) return;
    setState(() => _tab = next);
    if (next == 'archives' && _archivedItems.isEmpty) _loadArchives();
  }

  Future<void> _handleLogout() async {
    final ok = await confirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need to log in again to continue.',
      confirmLabel: 'Sign Out',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref.read(sessionProvider.notifier).logout();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final sessionUser =
        ref.watch(sessionProvider.select((s) => s?.user));
    final user = _profile ??
        sessionUser ??
        const AuthUser(id: 0, role: 'UNKNOWN');

    final displayName = (user.displayName?.isNotEmpty ?? false)
        ? user.displayName!
        : (user.username?.isNotEmpty ?? false)
            ? user.username!
            : 'User';

return Scaffold(
      backgroundColor: const Color(0xFFFBFBFA),
      body: SafeArea(
        child: Column(
          children: [
            _header(user, displayName),
            Expanded(
              child: _tab == 'profile'
                  ? _profileTab(user, displayName)
                  : _archivesTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AuthUser user, String displayName) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.arrow_back,
                      size: 20, color: Color(0xFF111827)),
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/admin'),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827)),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 12, color: AppColors.primary),
                    SizedBox(width: 3),
                    Text('ADMIN',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                for (final t in ['profile', 'archives'])
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _switchTab(t),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _tab == t ? Colors.black : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t[0].toUpperCase() + t.substring(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: _tab == t
                                ? Colors.white
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileTab(AuthUser user, String displayName) {
    final infoRows = <
        ({IconData icon, Color iconBg, Color iconFg, String label, String value})>[
      (
        icon: Icons.person_outline,
        iconBg: const Color(0xFFDBEAFE),
        iconFg: const Color(0xFF3B82F6),
        label: 'Username',
        value: displayName,
      ),
      (
        icon: Icons.mail_outline,
        iconBg: const Color(0xFFF3E8FF),
        iconFg: const Color(0xFFA855F7),
        label: 'Email',
        value: (user.email?.isNotEmpty ?? false) ? user.email! : 'N/A',
      ),
      (
        icon: Icons.verified_user_outlined,
        iconBg: const Color(0xFFDCFCE7),
        iconFg: const Color(0xFF22C55E),
        label: 'Business',
        value: (user.business?.isNotEmpty ?? false) ? user.business! : 'N/A',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < infoRows.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, color: Color(0xFFF9FAFB)),
                _infoRow(infoRows[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _actionCard([
          _Action(
            icon: Icons.upload_outlined,
            iconColor: const Color(0xFF6366F1),
            iconBg: const Color(0xFFEEF2FF),
            label: 'Bulk Import',
            onTap: () => context.push('/admin/bulk-import'),
          ),
        ]),
        const SizedBox(height: 12),
        _actionCard([
          _Action(
            icon: Icons.insert_drive_file_outlined,
            iconColor: const Color(0xFF6366F1),
            iconBg: const Color(0xFFEEF2FF),
            label: 'Summary',
            onTap: () => context.push('/admin/summary'),
          ),
        ]),
        const SizedBox(height: 20),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFFBFAFA),
            side: const BorderSide(color: Color(0xFFFFE4E6)),
            foregroundColor: const Color(0xFFF43F5E),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _handleLogout,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: 16),
              SizedBox(width: 8),
              Text('Sign Out',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
      ({IconData icon, Color iconBg, Color iconFg, String label, String value})
          row) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: row.iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(row.icon, size: 16, color: row.iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.label.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: Color(0xFF9CA3AF))),
                const SizedBox(height: 2),
                Text(row.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(List<_Action> actions) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: Color(0xFFF9FAFB)),
            _actionRow(actions[i]),
          ],
        ],
      ),
    );
  }

  Widget _actionRow(_Action action) {
    return InkWell(
      onTap: action.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: action.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(action.icon,
                  size: 17, color: action.iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(action.label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4B5563))),
            ),
            const Icon(Icons.chevron_right,
                size: 19, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }

  Widget _archivesTab() {
    if (_archivesLoading) {
      return const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: AppColors.primary));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Archived items are permanently deleted 30 days after being '
            'archived. Existing orders keep their item details.',
            style: TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                height: 1.4),
          ),
        ),
        _sectionHeader('Archived Items'),
if (_archivedItems.isEmpty)
          _emptyCard('No archived items')
        else
          ..._archivedItems.map(
              (item) => ArchivedItemCard(
                    item: item,
                    expanded: _expandedItem == item.id,
                    onToggle: () => setState(() => _expandedItem =
                        _expandedItem == item.id ? null : item.id),
                  )),
        const SizedBox(height: 20),
        _sectionHeader('Archived Orders'),
        if (_archivedOrders.isEmpty)
          _emptyCard('No archived orders')
        else
          ..._archivedOrders.map((order) => _archivedOrderRow(order)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: Color(0xFF9CA3AF))),
    );
  }

  Widget _emptyCard(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        children: [
          const Icon(Icons.archive_outlined,
              size: 26, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD1D5DB))),
        ],
      ),
    );
  }

Widget _archivedOrderRow(Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/admin/order/status/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text('#${order.id}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4B5563))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937))),
                    const SizedBox(height: 3),
                    Text(
                        '${order.totalSets} sets $kMiddleDot ${order.createdAt}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 19, color: Color(0xFFD1D5DB)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action {
  const _Action({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
}