import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/derive_username.dart';
import '../../core/utils/text_symbols.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/admin_shell.dart';
import '../../shared/scan_beep.dart';
import '../../shared/widgets.dart';

/// Mirrors `app/(admin)/admin/users/agents/[id]/page.tsx` +
/// `components/pages/agent/ItemAssignment.tsx` (PDF download omitted).
class AgentDetailScreen extends ConsumerStatefulWidget {
  const AgentDetailScreen({super.key, required this.agentId});

  final int agentId;

  @override
  ConsumerState<AgentDetailScreen> createState() => _AgentDetailScreenState();
}

class _AgentDetailScreenState extends ConsumerState<AgentDetailScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  Agent? _agent;
  List<Agent> _agents = const [];
  List<VariantAllItem> _allVariants = const [];
  bool _loading = true;
  bool _saving = false;
  bool _savingItems = false;
  bool _isEditing = false;

  List<int> _selected = const [];
  List<int> _saved = const [];
  Map<int, String> _variantCreatedAt = const {};
  final Set<int> _pendingRemoval = {};

  @override
  void initState() {
    super.initState();
    _load();
    _loadSecondary();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final agent = await repos.agent.getOne(widget.agentId);
      if (!mounted) return;
      final ids = <int>[];
      final createdAt = <int, String>{};
      for (final item in agent.assignedItems ?? const <AssignedItem>[]) {
        for (final v in item.variants) {
          ids.add(v.id);
          if (v.createdAt != null && v.createdAt!.isNotEmpty) {
            createdAt[v.id] = v.createdAt!;
          }
        }
      }
      setState(() {
        _agent = agent;
        _selected = ids;
        _saved = ids;
        _variantCreatedAt = createdAt;
        _nameCtrl.text = agent.displayName;
        _emailCtrl.text = agent.user.email ?? '';
        _contactCtrl.text = agent.contact ?? '';
        _loading = false;
      });
    } catch (e) {
      debugPrint('[AgentDetail] _load agent failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSecondary() async {
    try {
      final agents = await repos.agent.list();
      if (mounted) setState(() => _agents = agents);
    } catch (e) {
      debugPrint('[AgentDetail] _loadSecondary agents.list failed: $e');
    }
    try {
      final variants = await repos.item.allVariants();
      if (mounted) setState(() => _allVariants = variants);
    } catch (e) {
      debugPrint('[AgentDetail] _loadSecondary allVariants failed: $e');
    }
  }

  void _toggleVariant(int id) {
    setState(() {
      _selected = _selected.contains(id)
          ? _selected.where((i) => i != id).toList()
          : [..._selected, id];
    });
  }

  bool get _hasChanges {
    final a = [..._selected]..sort();
    final b = [..._saved]..sort();
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }

  /// Union of the all-variants feed and the variants actually assigned to this
  /// agent. The agent payload is authoritative for its own assignments, so
  /// already-assigned items stay visible (and scannable) even when
  /// `/api/items/variants/all/` is unavailable or filtered by business.
  List<VariantAllItem> _mergedVariants() {
    final byId = <int, VariantAllItem>{for (final v in _allVariants) v.id: v};
    for (final item in _agent?.assignedItems ?? const <AssignedItem>[]) {
      for (final v in item.variants) {
        if (byId.containsKey(v.id)) continue;
        final sizes = [
          for (final s in v.sizeRanges)
            VariantSize(sizeRange: s.sizeRange, stock: s.stock ?? 0),
        ];
        byId[v.id] = VariantAllItem(
          id: v.id,
          itemId: item.id,
          itemName: item.name,
          itemType: item.type ?? '',
          itemPrice: item.price,
          qrCode: v.qrCode,
          image: v.image,
          sizes: sizes,
          totalStock: sizes.fold(0, (sum, s) => sum + s.stock),
          uniqueSizes: sizes.map((s) => s.sizeRange).toSet().toList(),
        );
      }
    }
    return byId.values.toList();
  }

  Future<void> _saveItems() async {
    setState(() => _savingItems = true);
    try {
      await repos.agent.updateItems(widget.agentId, _selected);
      final updated = await repos.agent.getOne(widget.agentId);
      if (!mounted) return;
      final ids = <int>[];
      final createdAt = <int, String>{};
      for (final item in updated.assignedItems ?? const <AssignedItem>[]) {
        for (final v in item.variants) {
          ids.add(v.id);
          if (v.createdAt != null && v.createdAt!.isNotEmpty) {
            createdAt[v.id] = v.createdAt!;
          }
        }
      }
      setState(() {
        _agent = updated;
        _selected = ids;
        _saved = ids;
        _variantCreatedAt = createdAt;
        _pendingRemoval.clear();
        _savingItems = false;
      });
      AppToast.success(context, 'Items updated successfully');
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingItems = false);
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _saveDetails() async {
    setState(() => _saving = true);
    try {
      await repos.agent.update(widget.agentId, {
        'username': deriveUsername(_nameCtrl.text),
        'display_name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'contact': _contactCtrl.text.trim(),
      });
      if (!mounted) return;
      AppToast.success(context, 'Agent details updated');
      context.go('/admin/users');
    } catch (e) {
      if (mounted) {
        AppToast.error(context,
            e.toString().replaceFirst('Exception: ', ''));
      }
      setState(() => _saving = false);
    }
  }

  Future<void> _deleteAgent() async {
    final done = await showDialog<bool>(
      context: context,
      builder: (ctx) => DeleteWithTransferDialog(
        entityType: 'agent',
        entityName: _agent?.displayName ?? '',
        fetchDeleteInfo: () => repos.agent.deleteInfo(widget.agentId),
        onDelete: ({required pin, required action, transferToId}) async {
          await repos.agent.delete(widget.agentId, pin,
              action: action, transferToId: transferToId);
        },
      ),
    );
    if (mounted && done == true) context.go('/admin/users');
  }

  Future<void> _itemAction(String mode, int targetAgentId) async {
    if (mode == 'transfer') {
      await repos.agent.transferItems(widget.agentId, targetAgentId);
    } else {
      await repos.agent.copyItems(widget.agentId, targetAgentId);
    }
    final updated = await repos.agent.getOne(widget.agentId);
    if (!mounted) return;
    final ids = <int>[];
    final createdAt = <int, String>{};
    for (final item in updated.assignedItems ?? const <AssignedItem>[]) {
      for (final v in item.variants) {
        ids.add(v.id);
        if (v.createdAt != null && v.createdAt!.isNotEmpty) {
          createdAt[v.id] = v.createdAt!;
        }
      }
    }
    setState(() {
      _agent = updated;
      _selected = ids;
      _saved = ids;
      _variantCreatedAt = createdAt;
      _pendingRemoval.clear();
    });
  }

  Future<bool> _deleteAllItems() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete All Items?',
      message:
          'This will unassign all items currently assigned to this agent. This action cannot be undone.',
      confirmLabel: 'Delete All',
      destructive: true,
    );
    if (!ok) return false;
    try {
      await repos.agent.deleteAllItems(widget.agentId);
      final updated = await repos.agent.getOne(widget.agentId);
      if (!mounted) return true;
      setState(() {
        _agent = updated;
        _selected = const [];
        _saved = const [];
        _variantCreatedAt = const {};
        _pendingRemoval.clear();
      });
      AppToast.success(context, 'All assigned items deleted successfully');
      return true;
    } catch (e) {
      if (mounted) {
        AppToast.error(context,
            e.toString().replaceFirst('Exception: ', ''));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      activePath: '/admin/users',
      body: _loading
          ? const PageLoading()
          : _agent == null
              ? const EmptyState(
                  icon: Icons.person_off_outlined, title: 'Agent not found.')
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
                    Text('Agent Profile',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827))),
                    Text('PERSONNEL MANAGEMENT',
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
                  : () => setState(() => _isEditing = true),
              icon: Icon(
                _isEditing ? Icons.visibility_outlined : Icons.edit_outlined,
                size: 20,
                color: AppColors.heading,
              ),
            ),
            _MoreMenu(
              onCopy: () => _pickTarget('copy'),
              onTransfer: () => _pickTarget('transfer'),
              onDeleteAll: _deleteAllItems,
              onDeleteAgent: _deleteAgent,
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              _avatarSection(),
              const SizedBox(height: 16),
              if (_isEditing) _editForm() else _viewDetails(),
              const SizedBox(height: 8),
              _ItemAssignmentSection(
                agentId: widget.agentId,
                agentName: _agent?.displayName ?? '',
                variants: _mergedVariants(),
                selectedIds: _selected,
                savedIds: _saved,
                variantCreatedAt: _variantCreatedAt,
                pendingRemoval: _pendingRemoval,
                hasChanges: _hasChanges,
                savingItems: _savingItems,
                onToggle: _toggleVariant,
                onMarkRemoval: (id) => setState(() => _pendingRemoval.add(id)),
                onSave: _saveItems,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickTarget(String mode) async {
    final targets = _agents.where((a) => a.id != widget.agentId).toList();
    if (targets.isEmpty) {
      AppToast.error(context, 'No other agents available');
      return;
    }
    final targetId = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                mode == 'transfer' ? 'Transfer Items' : 'Copy Items',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            for (final t in targets)
              ListTile(
                title: Text(t.displayName),
                onTap: () => Navigator.pop(ctx, t.id),
              ),
          ],
        ),
      ),
    );
    if (targetId == null) return;
    try {
      setState(() => _saving = true);
      await _itemAction(mode, targetId);
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.success(context, mode == 'transfer'
          ? 'Items transferred successfully'
          : 'Items copied successfully');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _avatarSection() {
    final editing = _isEditing;
    return Center(
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: editing
                  ? const Color(0xFFEFF6FF)
                  : const HSLColor.fromAHSL(1, 220, 0.15, 0.75).toColor(),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 38,
              color: editing ? const Color(0xFF3B82F6) : const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 10),
          Text(_agent?.displayName ?? '',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827))),
          const Text('FIELD AGENT',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _viewDetails() {
    final a = _agent!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        children: [
          InfoRow('DISPLAY NAME', a.displayName),
          InfoRow('USERNAME', a.user.username ?? kEmDash),
          InfoRow('EMAIL', a.user.email ?? kEmDash),
          InfoRow('CONTACT', a.contact ?? kEmDash),
        ],
      ),
    );
  }

  Widget _editForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _editLabel('DISPLAY NAME'),
          _editField(_nameCtrl, onChanged: (_) => setState(() {})),
          const SizedBox(height: 14),
          _editLabel('SYSTEM USERNAME (AUTO-DERIVED)'),
          TextFormField(
            initialValue: deriveUsername(
                _nameCtrl.text.isEmpty ? 'agent' : _nameCtrl.text),
            enabled: false,
            style: const TextStyle(
                fontSize: 13, fontFamily: 'monospace'),
            decoration: _editDecoration(),
          ),
          const SizedBox(height: 14),
          _editLabel('EMAIL ADDRESS'),
          _editField(_emailCtrl),
          const SizedBox(height: 14),
          _editLabel('CONTACT NUMBER'),
          _editField(_contactCtrl),
          const SizedBox(height: 16),
          StockFlowButton(
            label: _saving ? 'Updating...' : 'Update Details',
            loading: _saving,
            onPressed: _saveDetails,
          ),
        ],
      ),
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

  Widget _editField(TextEditingController c, {ValueChanged<String>? onChanged}) =>
      TextFormField(
        controller: c,
        onChanged: onChanged,
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

// ---------------------------------------------------------------------------
// Overflow menu (Copy/Transfer items, Delete All Items, Delete Agent)
// ---------------------------------------------------------------------------

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.onCopy,
    required this.onTransfer,
    required this.onDeleteAll,
    required this.onDeleteAgent,
  });

  final VoidCallback onCopy;
  final VoidCallback onTransfer;
  final Future<bool> Function() onDeleteAll;
  final VoidCallback onDeleteAgent;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF374151)),
      onSelected: (value) {
        if (value == 'copy') onCopy();
        if (value == 'transfer') onTransfer();
        if (value == 'deleteAll') onDeleteAll();
        if (value == 'deleteAgent') onDeleteAgent();
      },
      itemBuilder: (ctx) => const [
        PopupMenuItem(
          value: 'copy',
          child: _MenuRow(Icons.copy_all_outlined, 'Copy Items'),
        ),
        PopupMenuItem(
          value: 'transfer',
          child: _MenuRow(Icons.swap_horiz, 'Transfer Items'),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'deleteAll',
          child: _MenuRow(Icons.delete_outline, 'Delete All Items',
              danger: true),
        ),
        PopupMenuItem(
          value: 'deleteAgent',
          child: _MenuRow(Icons.delete_outline, 'Delete Agent', danger: true),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.danger = false});
  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFDC2626) : const Color(0xFF374151);
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Item assignment — mirrors `ItemAssignment.tsx`
// ---------------------------------------------------------------------------

enum _AssignTab { recent, assigned }

class _ItemAssignmentSection extends ConsumerStatefulWidget {
  const _ItemAssignmentSection({
    required this.agentId,
    required this.agentName,
    required this.variants,
    required this.selectedIds,
    required this.savedIds,
    required this.variantCreatedAt,
    required this.pendingRemoval,
    required this.hasChanges,
    required this.savingItems,
    required this.onToggle,
    required this.onMarkRemoval,
    required this.onSave,
  });

  final int agentId;
  final String agentName;
  final List<VariantAllItem> variants;
  final List<int> selectedIds;
  final List<int> savedIds;
  final Map<int, String> variantCreatedAt;
  final Set<int> pendingRemoval;
  final bool hasChanges;
  final bool savingItems;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onMarkRemoval;
  final VoidCallback onSave;

  @override
  ConsumerState<_ItemAssignmentSection> createState() =>
      _ItemAssignmentSectionState();
}

class _ItemAssignmentSectionState extends ConsumerState<_ItemAssignmentSection> {
  _AssignTab _tab = _AssignTab.recent;

  /// Variants resolved live via `/api/items/by-qr/` that are missing from the
  /// 15-min-cached `/variants/all/` snapshot, merged inline so a scanned
  /// variant can still be toggled without waiting out the cache.
  final List<VariantAllItem> _liveResolved = [];

  DateTime get _recentCutoff {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - 1, 0, 1);
  }

  List<({VariantAllItem v, bool isUnsaved, bool removing})> get _all {
    final byId = <int, VariantAllItem>{
      for (final v in _liveResolved) v.id: v,
      for (final v in widget.variants) v.id: v,
    };
    final sorted = byId.values.toList()..sort((a, b) {
        final byName = _nameKey(a.itemName).compareTo(_nameKey(b.itemName));
        return byName != 0
            ? byName
            : a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase());
      });
    return [
      for (final v in sorted)
        (
          v: v,
          isUnsaved: !widget.savedIds.contains(v.id) &&
              widget.selectedIds.contains(v.id),
          removing: widget.pendingRemoval.contains(v.id),
        ),
    ];
  }

  static String _nameKey(String name) {
    final dash = name.indexOf('-');
    return dash > 0 ? name.substring(0, dash) : name;
  }

  List<int> get _recentIds {
    final recentlySaved = widget.savedIds.where((id) {
      final created = widget.variantCreatedAt[id];
      if (created == null) return false;
      final dt = DateTime.tryParse(created);
      return dt != null && dt.isAfter(_recentCutoff);
    });
    final unsaved = widget.selectedIds
        .where((id) => !widget.savedIds.contains(id));
    final combined = {...recentlySaved, ...unsaved}.toList();
    combined.sort((a, b) {
      final da = widget.variantCreatedAt[a];
      final db = widget.variantCreatedAt[b];
      final tA = da == null ? DateTime(2000) : DateTime.tryParse(da) ?? DateTime(2000);
      final tB = db == null ? DateTime(2000) : DateTime.tryParse(db) ?? DateTime(2000);
      return tB.compareTo(tA);
    });
    return combined;
  }

  List<({VariantAllItem v, bool isUnsaved, bool removing})> get _display {
    final all = _all;
    final selected = widget.selectedIds.toSet();
    final recent = _recentIds.toSet();
    final filtered = _tab == _AssignTab.recent
        ? all.where((e) => recent.contains(e.v.id)).toList()
        : all.where((e) => selected.contains(e.v.id)).toList();

    filtered.sort((a, b) {
      if (a.removing != b.removing) return a.removing ? 1 : -1;
      final ka = _nameKey(a.v.itemName);
      final kb = _nameKey(b.v.itemName);
      final byKey = ka.toLowerCase().compareTo(kb.toLowerCase());
      if (byKey != 0) return byKey;
      final byFull = a.v.itemName.toLowerCase().compareTo(b.v.itemName.toLowerCase());
      if (byFull != 0) return byFull;
      final ca = widget.variantCreatedAt[a.v.id];
      final cb = widget.variantCreatedAt[b.v.id];
      final ta = ca == null
          ? DateTime(2000)
          : DateTime.tryParse(ca) ?? DateTime(2000);
      final tb = cb == null
          ? DateTime(2000)
          : DateTime.tryParse(cb) ?? DateTime(2000);
      return tb.compareTo(ta);
    });
    return filtered;
  }

  /// Resolves a scanned QR to a variant and toggles it, returning an inline
  /// feedback message so the (modal, continuously-open) scanner can show
  /// progress. The primary source is the local [widget.variants] snapshot.
  /// That snapshot comes from `/api/items/variants/all/` which is cached for
  /// 15 minutes, so a just-created (or otherwise missing) variant is not in it
  /// even though it still resolves live via the authoritative
  /// `/api/items/by-qr/` endpoint (the same one the order flow and web app
  /// use). When the local match misses, fall back to that live lookup and
  /// merge the resolved row inline.
  Future<({String message, bool isError})> _handleScan(
      String qr, {required bool remove}) async {
    final trimmed = qr.trim();
    var v = widget.variants.where((x) => x.qrCode == trimmed).toList();
    if (v.isEmpty) {
      try {
        final itemQr = await repos.item.byQr(trimmed);
        if (!mounted) {
          return (message: 'Variant not found with this QR code', isError: true);
        }
        final matched = itemQr.matchedVariantId == null
            ? null
            : itemQr.variants
                .where((x) => x.id == itemQr.matchedVariantId)
                .toList();
        final resolved =
            (matched == null || matched.isEmpty) ? null : matched.first;
        if (resolved == null) {
          AppToast.error(context, 'Variant not found with this QR code');
          return (message: 'Variant not found with this QR code', isError: true);
        }
        final display = _synthesizeFromQr(itemQr, resolved);
        if (display == null) {
          AppToast.error(context, 'Variant not found with this QR code');
          return (message: 'Variant not found with this QR code', isError: true);
        }
        final known = widget.variants.where((x) => x.id == display.id).toList();
        v = known.isEmpty ? [display] : known;
        if (known.isEmpty && !_all.any((e) => e.v.id == display.id)) {
          setState(() => _liveResolved.add(display));
        }
      } catch (_) {
        AppToast.error(context, 'Variant not found with this QR code');
        return (message: 'Variant not found with this QR code', isError: true);
      }
    }
    final variant = v.first;
    if (remove) {
      if (!widget.selectedIds.contains(variant.id)) {
        AppToast.error(context, '${variant.itemName} is not assigned to this agent');
        return (
          message: '${variant.itemName} is not assigned to this agent',
          isError: true,
        );
      }
      widget.onToggle(variant.id);
      widget.onMarkRemoval(variant.id);
      AppToast.success(context, '${variant.itemName} marked for removal');
      return (message: '${variant.itemName} marked for removal', isError: false);
    } else {
      if (!widget.selectedIds.contains(variant.id)) {
        widget.onToggle(variant.id);
        AppToast.success(context, '${variant.itemName} added');
        return (message: '${variant.itemName} added', isError: false);
      } else {
        AppToast.success(context, '${variant.itemName} already selected');
        return (message: '${variant.itemName} already selected', isError: false);
      }
    }
  }

  /// Builds a [VariantAllItem] from the live `/api/items/by-qr/` response so a
  /// variant missing from the cached snapshot can still be toggled/saved.
  VariantAllItem? _synthesizeFromQr(ItemQR itemQr, ItemVariantQR resolved) {
    return VariantAllItem(
      id: resolved.id,
      itemId: itemQr.id,
      itemName: itemQr.name,
      itemType: itemQr.type ?? '',
      itemPrice: itemQr.price,
      qrCode: resolved.qrCode,
      image: resolved.image,
      sizes: resolved.sizes,
      totalStock: resolved.totalStock,
      uniqueSizes: resolved.sizes.map((s) => s.sizeRange).toSet().toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = _display;
    final selectedCount = widget.selectedIds.length;
    final recentCount = _recentIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('Items',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827))),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$selectedCount',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
            if (widget.hasChanges) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Unsaved',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309))),
              ),
            ],
            const Spacer(),
            SizedBox(
              height: 38,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed:
                    widget.hasChanges && !widget.savingItems ? widget.onSave : null,
                child: widget.savingItems
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _scanButton(
                label: 'Add',
                icon: Icons.qr_code_scanner,
                onTap: () => _openScanner(remove: false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _scanButton(
                label: 'Remove',
                icon: Icons.qr_code_scanner,
                danger: true,
                enabled: selectedCount > 0,
                onTap: () => _openScanner(remove: true),
              ),
            ),
          ],
        ),
        if (selectedCount > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _tabPill('Recent ($recentCount)', _AssignTab.recent),
                ),
                Expanded(
                  child:
                      _tabPill('Assigned ($selectedCount)', _AssignTab.assigned),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (display.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                _tab == _AssignTab.recent
                    ? 'No recently added variants'
                    : 'No assigned variants',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
            ),
          )
        else
          for (final e in display) _variantRow(e),
      ],
    );
  }

  Widget _tabPill(String label, _AssignTab tab) {
    final active = _tab == tab;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _tab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : const Color(0xFF6B7280),
            )),
      ),
    );
  }

  Widget _scanButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool danger = false,
    bool enabled = true,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: danger
                  ? (enabled
                      ? const Color(0xFFFECACA)
                      : const Color(0xFFF3F4F6))
                  : const Color(0xFFE5E7EB),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 17,
                  color: danger
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF4B5563)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: danger
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF4B5563))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _variantRow(
      ({VariantAllItem v, bool isUnsaved, bool removing}) e) {
    final v = e.v;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: e.removing
            ? const Color(0xFFFEF2F2)
            : e.isUnsaved
                ? const Color(0xFFFFFBEB)
                : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: e.removing
              ? const Color(0xFFFECACA)
              : e.isUnsaved
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFF3F4F6),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 40,
              child: v.image != null && v.image!.isNotEmpty
                  ? AppImage(v.image, previewEnabled: true)
                  : Container(
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(Icons.inventory_2_outlined,
                          size: 16, color: Color(0xFFD1D5DB)),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(v.itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827))),
                    ),
                    if (e.removing)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('Removing',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626))),
                      )
                    else if (e.isUnsaved)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('Unsaved',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309))),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Rs. ${v.itemPrice}${v.itemType.isNotEmpty ? ' $kMiddleDot ${v.itemType}' : ''}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF))),
                if (v.sizes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final s in v.sizes)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('${s.sizeRange}:${s.stock}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6B7280))),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openScanner({required bool remove}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AssignScanSheet(
        remove: remove,
        onUnsavedCount: () => remove
            ? widget.pendingRemoval.length
            : widget.selectedIds
                .where((id) => !widget.savedIds.contains(id))
                .length,
        onScanned: (qr) => _handleScan(qr, remove: remove),
      ),
    );
  }
}

class _AssignScanSheet extends StatefulWidget {
  const _AssignScanSheet({
    required this.remove,
    required this.onUnsavedCount,
    required this.onScanned,
  });
  final bool remove;
  final int Function() onUnsavedCount;
  final Future<({String message, bool isError})> Function(String qr) onScanned;

  @override
  State<_AssignScanSheet> createState() => _AssignScanSheetState();
}

class _AssignScanSheetState extends State<_AssignScanSheet> {
  late int _unsaved = widget.onUnsavedCount();
  String? _lastMessage;
  bool _lastIsError = false;
  String? _lastRaw;
  DateTime? _lastHandledAt;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Scan QR codes',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.remove
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                          _unsaved == 0 ? 'ready' : '$_unsaved unsaved',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: widget.remove
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF16A34A)),
                        ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            if (_lastMessage != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _lastIsError
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _lastIsError
                          ? const Color(0xFFFECACA)
                          : const Color(0xFFBBF7D0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _lastIsError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 16,
                        color: _lastIsError
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _lastMessage!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: MobileScanner(
                    onDetect: (capture) async {
                      final barcode = capture.barcodes.isNotEmpty
                          ? capture.barcodes.first
                          : null;
                      final raw = barcode?.rawValue;
                      if (raw == null || raw.isEmpty) return;
                      final now = DateTime.now();
                      final lastHandledAt = _lastHandledAt;
                      final isRepeat = _lastRaw == raw &&
                          lastHandledAt != null &&
                          now.difference(lastHandledAt) <
                              const Duration(milliseconds: 1500);
                      if (isRepeat) return;
                      _lastRaw = raw;
                      _lastHandledAt = now;
                      playScanBeep();
                      final result = await widget.onScanned(raw);
                      if (!mounted) return;
                      setState(() {
                        _unsaved = widget.onUnsavedCount();
                        _lastMessage = result.message;
                        _lastIsError = result.isError;
                      });
                    },
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