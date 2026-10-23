import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

class ItemCategoriesScreen extends StatefulWidget {
  const ItemCategoriesScreen({super.key});

  @override
  State<ItemCategoriesScreen> createState() => _ItemCategoriesScreenState();
}

class _ItemCategoriesScreenState extends State<ItemCategoriesScreen> {
  final _newController = TextEditingController();
  final _editController = TextEditingController();

  List<ItemCategory> _categories = const [];
  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  int? _editingId;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load(showSpinner: false);
  }

  @override
  void dispose() {
    _newController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final categories = await repos.item.categories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _reload() async {
    try {
      final categories = await repos.item.categories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Failed to refresh categories');
      }
    }
  }

  Future<void> _addCategory() async {
    final name = _newController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await repos.item.createCategory(name);
      if (!mounted) return;
      _newController.clear();
      await _reload();
      if (mounted) AppToast.success(context, 'Category added');
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          'Could not add category',
          description: e.toString(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _startEdit(ItemCategory category) {
    setState(() {
      _editingId = category.id;
      _editController.text = category.name;
      _editController.selection =
          TextSelection.collapsed(offset: _editController.text.length);
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _editController.clear();
    });
  }

  Future<void> _saveEdit(ItemCategory category) async {
    final name = _editController.text.trim();
    if (name.isEmpty || _busyId != null) return;
    if (name == category.name) {
      _cancelEdit();
      return;
    }
    setState(() => _busyId = category.id);
    try {
      await repos.item.updateCategory(category.id, name);
      if (!mounted) return;
      _cancelEdit();
      await _reload();
      if (mounted) AppToast.success(context, 'Category updated');
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          'Could not update category',
          description: e.toString(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _deleteCategory(ItemCategory category) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${category.name}?',
      message:
          'Existing items keep their saved category. New items cannot select it.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = category.id);
    try {
      await repos.item.deleteCategory(category.id);
      if (!mounted) return;
      await _reload();
      if (mounted) AppToast.success(context, 'Category deleted');
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          'Could not delete category',
          description: e.toString(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFA),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => context.canPop()
                ? context.pop()
                : context.go('/admin/profile?tab=settings'),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.arrow_back,
                size: 24,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Item Categories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const PageLoading(label: 'Loading categories...');
    }
    if (_loadError != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Failed to load categories',
        subtitle: _loadError,
        action: FilledButton(
          onPressed: _load,
          child: const Text('Retry'),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const Text(
          'Manage the categories available when creating items.',
          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 16),
        _addCard(),
        const SizedBox(height: 12),
        if (_categories.isEmpty) _emptyCard() else _listCard(),
      ],
    );
  }

  Widget _addCard() {
    final canAdd = _newController.text.trim().isNotEmpty && !_saving;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _newController,
              textCapitalization: TextCapitalization.words,
              maxLength: 100,
              decoration: const InputDecoration(
                hintText: 'New category',
                counterText: '',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _addCategory(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Add category',
            onPressed: canAdd ? _addCategory : null,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _listCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _categories.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _categoryRow(_categories[i]),
          ],
        ],
      ),
    );
  }

  Widget _categoryRow(ItemCategory category) {
    if (_editingId == category.id) {
      final busy = _busyId != null;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _editController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
                decoration: const InputDecoration(
                  counterText: '',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _saveEdit(category),
              ),
            ),
            IconButton(
              tooltip: 'Save category',
              onPressed: busy || _editController.text.trim().isEmpty
                  ? null
                  : () => _saveEdit(category),
              icon: const Icon(Icons.check, color: AppColors.primary),
            ),
            IconButton(
              tooltip: 'Cancel edit',
              onPressed: busy ? null : _cancelEdit,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
    }

    final busy = _busyId != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Edit category',
            onPressed: busy ? null : () => _startEdit(category),
            icon: const Icon(
              Icons.edit_outlined,
              size: 20,
              color: Color(0xFF9CA3AF),
            ),
          ),
          IconButton(
            tooltip: 'Delete category',
            onPressed: busy ? null : () => _deleteCategory(category),
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: const Column(
        children: [
          Icon(Icons.sell_outlined, size: 26, color: Color(0xFFE5E7EB)),
          SizedBox(height: 6),
          Text(
            'No categories yet',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFD1D5DB),
            ),
          ),
        ],
      ),
    );
  }
}
