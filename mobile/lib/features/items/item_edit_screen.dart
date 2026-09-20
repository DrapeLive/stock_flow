import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/price_input.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../providers.dart';
import '../../shared/widgets.dart';
import 'variant_form.dart';

class _EditableSize {
  _EditableSize({
    required this.localId,
    required this.size,
    required this.stock,
  });
  final String localId;
  final String size;
  int stock;
}

class _VariantGroup {
  _VariantGroup({
    required this.backendId,
    this.imageUrl,
    this.newImagePath,
    this.displayOrder = '',
    required this.sizes,
  });

  final int backendId; // negative when not yet saved
  String? imageUrl;
  String? newImagePath;
  String displayOrder;
  final List<_EditableSize> sizes;

  bool get isNew => backendId < 0;
}

/// Mirrors `app/(admin)/admin/items/edit/[id]/page.tsx`.
class ItemEditScreen extends ConsumerStatefulWidget {
  const ItemEditScreen({super.key, required this.itemId});
  final int itemId;

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  String _name = '';
  String _description = '';
  String _price = '';
  String _type = 'gents';
  List<_VariantGroup> _groups = [];
  final Set<int> _open = {};
  Map<String, List<String>> _itemSizes = const {};

  String _localSeq = '';

  @override
  void initState() {
    super.initState();
    _localSeq = DateTime.now().microsecondsSinceEpoch.toString();
    _load();
  }

  Future<void> _load() async {
    final sizesFuture = repos.item.sizeRanges();
    final Item item;
    try {
      item = await repos.item.getOne(widget.itemId);
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
      return;
    }
    try {
      final sizeData = await sizesFuture;
      final byType =
          sizeData['item_creation_sizes_by_type'] as Map<String, dynamic>? ??
              const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _name = item.name;
        _description = item.description ?? '';
        _price = item.price;
        _type = (item.type == 'kids') ? 'kids' : 'gents';
        _itemSizes = {
          for (final e in byType.entries)
            e.key: List<String>.from(e.value as List? ?? const []),
        };
        _groups = _buildGroups(item.variants);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_VariantGroup> _buildGroups(List<ItemVariant> variants) {
    final groups = <_VariantGroup>[];
    for (final v in variants) {
      final group = _VariantGroup(
        backendId: v.id,
        imageUrl: v.image,
        displayOrder:
            (v.displayOrder == null || v.displayOrder!.isEmpty) ? '' : v.displayOrder!,
        sizes: [
          for (final s in v.sizes)
            _EditableSize(
              localId: '$_localSeq-${v.id}-${s.size}',
              size: s.size ?? '',
              stock: s.stock,
            ),
        ],
      );
      groups.add(group);
    }
    return groups;
  }

bool get _isValid {
    if (_name.trim().isEmpty || _groups.isEmpty) return false;
    final price = parseItemPrice(_price.trim());
    return price != null && price > 0;
  }

  bool get _isBusinessAdmin {
    final business =
        ref.read(sessionProvider.select((s) => s?.user.business));
    return business == 'kids' || business == 'gents';
  }

  String? get _priceError {
    final raw = _price.trim();
    if (raw.isEmpty) return null;
    final v = parseItemPrice(raw);
    if (v == null || v <= 0) return 'Enter a price greater than 0';
    return null;
  }

  List<String> _sizesForType() =>
      _itemSizes[(_type == 'kids' || _type == 'gents') ? _type : 'gents'] ??
      const [];

  // â”€â”€ CRUD on groups â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _startAdd() {
    final available = _sizesForType();
    final draft = ColorVariantDraft(
      tempId: 'add-$_localSeq',
      sizeRange: available.isNotEmpty ? available.first : 'S,M,L,XL',
      perSizeStock: const {},
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VariantEditorScreen(
        commonName: _name,
        commonPrice: _price,
        commonType: _type,
        itemSizes: available,
        initial: draft,
        isEdit: false,
        variantIndex: _groups.length + 1,
        onSave: (saved) {
          _localSeq = DateTime.now().microsecondsSinceEpoch.toString();
          final tempId = -(_localSeq.hashCode & 0x7FFFFFFF);
          final pairs = flattenVariantSizes(saved, _type);
          final group = _VariantGroup(
            backendId: tempId,
            newImagePath: saved.imagePath,
            displayOrder: saved.displayOrder ?? '',
            sizes: [
              for (final p in pairs)
                _EditableSize(
                    localId: '$_localSeq-${p.size}', size: p.size, stock: p.stock),
            ],
          );
          setState(() {
            _groups = [..._groups, group];
          });
          Navigator.of(context).pop();
        },
        onBack: () => Navigator.of(context).pop(),
      ),
    ));
  }

  void _updateStock(String localId, String raw) {
    final parsed = int.tryParse(raw) ?? 0;
    setState(() {
      for (final g in _groups) {
        for (final s in g.sizes) {
          if (s.localId == localId) s.stock = parsed;
        }
      }
    });
  }

  void _updateDisplayOrder(int backendId, String value) {
    setState(() {
      for (final g in _groups) {
        if (g.backendId == backendId) g.displayOrder = value;
      }
    });
  }

  void _deleteGroup(_VariantGroup g) {
    setState(() {
      _groups = _groups.where((x) => x.backendId != g.backendId).toList();
    });
  }

  Future<void> _pickImageFor(_VariantGroup g) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      g.newImagePath = picked.path;
    });
  }

  // â”€â”€ Save â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final groupedPayload = <Map<String, dynamic>>[];
      final existingWithNewImage =
          <({int variantId, String path})>[];
      for (final g in _groups) {
        final sizes = [
          for (final s in g.sizes) {'size': s.size, 'stock': s.stock},
        ];
        final entry = <String, dynamic>{};
        if (!g.isNew) entry['id'] = g.backendId;
        entry['sizes'] = sizes;
        if (!g.isNew && g.imageUrl == null && g.newImagePath == null) {
          entry['remove_image'] = true;
        }
        final doValue = g.displayOrder.trim();
        entry['display_order'] = doValue.isEmpty ? null : doValue;
        if (g.newImagePath != null && !g.isNew) {
          existingWithNewImage
              .add((variantId: g.backendId, path: g.newImagePath!));
        }
        groupedPayload.add(entry);
      }

      final payload = <String, dynamic>{
        'name': _name,
        'price': _price,
        'type': _type,
        if (_description.isNotEmpty) 'description': _description,
        'variants': groupedPayload,
      };

      final updated = await repos.item.update(widget.itemId, payload);

      // Upload images: existing variants (own id) + newly created variants
      // matched by position after excluding known existing ids.
      final existingIds = {for (final g in _groups) if (!g.isNew) g.backendId};
      final createdVariants = [
        for (final v in updated.variants)
          if (!existingIds.contains(v.id)) v,
      ];
      final newImages = [
        for (final g in _groups)
          if (g.isNew && g.newImagePath != null)
            (path: g.newImagePath!, id: g.backendId),
      ];
      final jobs = <({int variantId, String path})>[
        ...existingWithNewImage,
        for (var i = 0; i < newImages.length; i++)
          if (i < createdVariants.length)
            (variantId: createdVariants[i].id, path: newImages[i].path),
      ];
      for (final job in jobs) {
        await repos.item.patchVariantImage(job.variantId, job.path);
      }

      if (!mounted) return;
      AppToast.show(context, 'Item updated successfully');
      context.canPop() ? context.pop() : context.go('/admin/items');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.show(context, 'Failed to update item',
            description: '$e', isError: true);
      }
    }
  }

  // â”€â”€ Delete â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _handleDelete() async {
    final user = ref.read(sessionProvider.select((s) => s?.user));
    if (user?.isSuperuser == true) {
      final ok = await confirmDialog(context,
          title: 'Delete this item?',
          message: 'This cannot be undone.',
          confirmLabel: 'Delete',
          destructive: true);
      if (!ok) return;
      await _confirmDeletePin(null);
      return;
    }
    final pin = await PinDialog.show(context,
        title: 'Delete Item',
        message: 'This item and all its variants will be removed.');
    if (pin == null) return;
    await _confirmDeletePin(pin);
  }

  Future<void> _confirmDeletePin(String? pin) async {
    try {
      await repos.item.deleteWithPin(widget.itemId, pin ?? '');
      if (mounted) {
        AppToast.show(context, 'Item deleted successfully');
        context.canPop() ? context.pop() : context.go('/admin/items');
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Failed to delete item',
          description: '$e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
body: SafeArea(
        child: _loading
            ? const PageLoading(label: 'Loading itemâ€¦')
            : _loadError != null
                ? EmptyState(
                    icon: Icons.error_outline,
                    title: 'Failed to load item',
                    subtitle: _loadError,
                    action: Align(
                      child: StockFlowButton(
                        label: 'Retry',
                        onPressed: _load,
                        expand: false,
                      ),
                    ),
)
                : Column(
                    children: [
                      _editHeader(),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            _avatarBlock(),
                            const SizedBox(height: 20),
                            _itemDetailsCard(),
                            const SizedBox(height: 20),
                            _variantsSection(),
                            const SizedBox(height: 12),
                            StockFlowButton(
                              label: _saving ? 'Saving…' : 'Save Changes',
                              enabled: _isValid && !_saving,
                              onPressed: _save,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _editHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => context.canPop()
            ? context.pop()
            : context.go('/admin/items'),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.arrow_back, size: 24, color: Color(0xFF9CA3AF)),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const Text('Edit Item',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827))),
                Text('ID #${widget.itemId}',
                    style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          IconButton(
            onPressed: _handleDelete,
            icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFF87171)),
          ),
        ],
      ),
    );
  }

  Widget _avatarBlock() {
    final first = _groups.isEmpty ? null : _groups.first;
    final image = first?.newImagePath ?? first?.imageUrl;
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
          ),
          clipBehavior: Clip.antiAlias,
child: image != null
              ? image.startsWith('http') || image.startsWith('/')
                  ? AppImage(image, previewEnabled: true)
                  : Image.file(File(image), fit: BoxFit.cover)
              : const Icon(Icons.inventory_2_outlined,
                  size: 34, color: AppColors.primary),
        ),
        const SizedBox(height: 10),
        Text(_name.isEmpty ? 'â€”' : _name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
      ],
    );
  }

  Widget _itemDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
const Text('ITEM DETAILS',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          StockFlowTextField(
            label: 'Name *',
            hint: 'e.g. Classic Round-Neck Tee',
            initialText: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(100)],
            onChanged: (v) => setState(() => _name = v),
          ),
          const SizedBox(height: 12),
          StockFlowTextField(
            label: 'Description',
            hint: 'Describe the item…',
            initialText: _description,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 6,
            onChanged: (v) => setState(() => _description = v),
          ),
          const SizedBox(height: 12),
          if (_isBusinessAdmin)
            _priceFieldEdit()
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _priceFieldEdit()),
                const SizedBox(width: 12),
                Expanded(child: _typeBox()),
              ],
            ),
        ],
      ),
    );
  }

  Widget _priceFieldEdit() {
    return StockFlowTextField(
      label: 'Price *',
      hint: '0.00',
      prefixText: '₹ ',
      initialText: _price,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [PriceTextInputFormatter()],
      textInputAction: TextInputAction.done,
      errorText: _priceError,
      onChanged: (v) => setState(() => _price = v),
    );
  }

  Widget _typeBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EditLabel('Type'),
        const SizedBox(height: 8),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          alignment: Alignment.centerLeft,
          child: Text(_type.capitalized,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280))),
        ),
      ],
    );
  }

Widget _variantsSection() {
    final totalSizes = _groups.fold<int>(0, (s, g) => s + g.sizes.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Variants',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827))),
            ),
            Text(
              '${_groups.length} variant${_groups.length != 1 ? 's' : ''}, $totalSizes size${totalSizes != 1 ? 's' : ''}',
              style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_groups.isEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFEDD5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text('At least one variant is required.',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFFD97706))),
              ],
            ),
          ),
        for (final g in _groups)
          _variantGroupCard(g),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _startAdd,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 16, color: Color(0xFF9CA3AF)),
                SizedBox(width: 6),
                Text('Add Variant',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _variantGroupCard(_VariantGroup g) {
    final isOpen = _open.contains(g.backendId);
    final label =
        g.displayOrder.trim().isEmpty ? '${_groups.indexOf(g) + 1}' : g.displayOrder.trim();
    final currentImage = g.newImagePath ?? g.imageUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _pickImageFor(g),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: currentImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: currentImage.startsWith('http') ||
                                    currentImage.startsWith('/')
                                ? AppImage(currentImage)
                                : Image.file(File(currentImage),
                                    fit: BoxFit.cover),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined,
                            size: 16, color: Color(0xFFD1D5DB)),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => setState(() {
                    if (isOpen) {
                      _open.remove(g.backendId);
                    } else {
                      _open.add(g.backendId);
                    }
                  }),
                  child: Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Variant #$label',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827))),
                        Text('${g.sizes.length} size${g.sizes.length != 1 ? 's' : ''}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() {
                    if (isOpen) {
                      _open.remove(g.backendId);
                    } else {
                      _open.add(g.backendId);
                    }
                  }),
                  child: Transform.rotate(
                    angle: isOpen ? 3.1416 : 0,
                    child: const Icon(Icons.keyboard_arrow_down,
                        size: 18, color: Color(0xFF9CA3AF)),
                  ),
                ),
                const SizedBox(width: 4),
                if (_groups.length > 1)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'Remove this variant?',
                        confirmLabel: 'Remove',
                        destructive: true,
                      );
                      if (ok) _deleteGroup(g);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 16, color: Color(0xFFF87171)),
                    ),
                  ),
              ],
            ),
          ),
          if (isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF3F4F6)),
                    ),
                    child: Row(
                      children: [
                        const Text('Display Order',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF9CA3AF))),
                        const SizedBox(width: 10),
Expanded(
                          child: SizedBox(
                            height: 32,
                            child: StockFlowTextField(
                              initialText: g.displayOrder,
                              keyboardType: TextInputType.number,
                              hint: '0',
                              fillColor: Colors.white,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              borderRadius: 8,
                              onChanged: (v) =>
                                  _updateDisplayOrder(g.backendId, v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final s in g.sizes)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            alignment: Alignment.center,
                            child: Text(s.size,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4B5563))),
                          ),
                          const Expanded(
                            child: Text('Stock',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF9CA3AF))),
                          ),
SizedBox(
                            width: 76,
                            child: StockFlowTextField(
                              initialText: '${s.stock}',
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              hint: '0',
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              borderRadius: 8,
                              onChanged: (v) => _updateStock(s.localId, v),
                            ),
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
}

class _EditLabel extends StatelessWidget {
  const _EditLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)));
  }
}

extension on String {
  String get capitalized =>
      isEmpty ? this : this[0].toUpperCase() + substring(1);
}