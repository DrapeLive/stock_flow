import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/price_input.dart';
import '../../core/utils/text_symbols.dart';
import '../../data/repositories.dart';
import '../../providers.dart';
import '../../shared/widgets.dart';
import 'variant_form.dart';

enum WizardStep { common, list, form }

/// Mirrors `app/(admin)/admin/items/new/page.tsx` (3-step wizard).
/// Type chip + common details -> color variants -> create.
class ItemWizardScreen extends ConsumerStatefulWidget {
  const ItemWizardScreen({super.key});

  @override
  ConsumerState<ItemWizardScreen> createState() => _ItemWizardScreenState();
}

class _ItemWizardScreenState extends ConsumerState<ItemWizardScreen> {
  WizardStep _step = WizardStep.common;
  String _editingId = '';

String _name = '';
  String _description = '';
  String _price = '';
  String _type = '';
  List<ColorVariantDraft> _variants = [];
  ColorVariantDraft? _draft;
  bool _submitting = false;
  bool _rangeLoading = true;
  Map<String, List<String>> _itemSizes = const {};
  String _tempSeq = '';

  /// True for an admin scoped to one business (gents/kids). They have no Type
  /// selector: their item type is fixed to their business.
  bool get _hasBusiness {
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

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider.select((s) => s?.user));
    final business = user?.business;
    if (business == 'kids' || business == 'gents') {
      _type = business!;
    }
    _tempSeq = _randomId();
    _loadRanges();
  }

  String _randomId() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  List<String> _sizesFor(String type) =>
      _itemSizes[(type == 'kids' || type == 'gents') ? type : 'gents'] ??
      const [];

  Future<void> _loadRanges() async {
    try {
      final data = await repos.item.sizeRanges();
      final byType = data['item_creation_sizes_by_type'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      final sizes = <String, List<String>>{
        for (final e in byType.entries)
          e.key: List<String>.from(e.value as List? ?? const []),
      };
      if (mounted) {
        setState(() {
          _itemSizes = sizes;
          _rangeLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _rangeLoading = false);
    }
  }

  ColorVariantDraft _blankVariant() {
    final available = _sizesFor(_type);
    return ColorVariantDraft(
      tempId: '$_tempSeq-${_variants.length + 1}',
      sizeRange: available.isNotEmpty ? available.first : 'S,M,L,XL',
      perSizeStock: const {},
    );
  }

  void _goCommonNext() {
    if (_variants.isNotEmpty) {
      setState(() => _step = WizardStep.list);
    } else {
      setState(() {
        _draft = _blankVariant();
        _step = WizardStep.form;
      });
    }
  }

  void _startAdd() {
    setState(() {
      _editingId = '';
      _draft = _blankVariant();
      _step = WizardStep.form;
    });
  }

  void _startEdit(String id) {
    final existing = _variants.where((v) => v.tempId == id).firstOrNull;
    if (existing == null) return;
    setState(() {
      _editingId = id;
      _draft = existing;
      _step = WizardStep.form;
    });
  }

  void _saveColor(ColorVariantDraft saved) {
    setState(() {
      if (_editingId.isNotEmpty) {
        _variants = [
          for (final v in _variants)
            if (v.tempId == _editingId) saved.copyWith(tempId: v.tempId) else v,
        ];
      } else {
        _variants = [..._variants, saved];
      }
      _draft = null;
      _editingId = '';
      _step = WizardStep.list;
    });
  }

  void _backFromForm() {
    setState(() {
      _draft = null;
      _editingId = '';
      _step = _variants.isNotEmpty ? WizardStep.list : WizardStep.common;
    });
  }

  bool get _commonValid {
    if (_name.trim().isEmpty) return false;
    final price = parseItemPrice(_price.trim());
    if (price == null || price <= 0) return false;
    return _hasBusiness || _type == 'gents' || _type == 'kids';
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final payload = <ItemVariantPayload>[];
      for (var i = 0; i < _variants.length; i++) {
        final v = _variants[i];
        payload.add(ItemVariantPayload(
          imagePath: v.imagePath,
          sizes: flattenVariantSizes(v, _type),
          displayOrder: v.displayOrder ?? '${i + 1}',
        ));
      }
await repos.item.createMultipart(
        name: _name,
        description: _description,
        price: parseItemPrice(_price.trim()) ?? 0,
        type: _type,
        variants: payload,
      );
      if (!mounted) return;
      AppToast.show(context, 'Item created successfully',
          description: 'Item "_name" has been added to inventory'.replaceAll('_name', _name));
      context.canPop() ? context.pop() : context.go('/admin/items');
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        AppToast.show(context, 'Failed to create item',
          description: '$e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == WizardStep.form && _draft != null) {
      return VariantEditorScreen(
        commonName: _name,
        commonPrice: _price,
        commonType: _type,
        itemSizes: _sizesFor(_type),
        initial: _draft!,
        isEdit: _editingId.isNotEmpty,
        variantIndex: _editingId.isNotEmpty
            ? _variants.indexWhere((v) => v.tempId == _editingId) + 1
            : _variants.length + 1,
        onSave: _saveColor,
        onBack: _backFromForm,
      );
    }

return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _step == WizardStep.common
            ? _commonStep()
            : _listStep(),
      ),
    );
  }

  // ---- Step 1: Item Details ----------------------------------------------------------------------------------------------------

  Widget _commonStep() {
    return Column(
      children: [
        _wizardHeader(
            eyebrow: 'Step 1 of 2',
            title: 'Item Details',
            onBack: () => context.canPop()
                ? context.pop()
                : context.go('/admin/items')),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'These details are shared across all color variants you\'ll add next.',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF), height: 1.4),
            ),
          ),
        ),
Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              StockFlowTextField(
                label: 'Name *',
                hint: 'e.g. Classic Round-Neck Tee',
                initialText: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                onChanged: (v) => setState(() => _name = v),
              ),
              const SizedBox(height: 16),
              StockFlowTextField(
                label: 'Description',
                hint: 'Describe the item…',
                initialText: _description,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 6,
                onChanged: (v) => setState(() => _description = v),
              ),
              const SizedBox(height: 16),
              _hasBusiness
                  ? _priceField()
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _priceField()),
                        const SizedBox(width: 12),
                        Expanded(child: _typeField()),
                      ],
                    ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: StockFlowButton(
            label: 'Next $kEmDash Add Colors',
            enabled: _commonValid,
            onPressed: _goCommonNext,
          ),
        ),
      ],
    );
  }

Widget _priceField() {
    return StockFlowTextField(
      label: 'Price *',
      hint: '0.00',
      prefixText: '$kRupee ',
      initialText: _price,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: const [PriceTextInputFormatter()],
      textInputAction: TextInputAction.done,
      errorText: _priceError,
      onChanged: (v) => setState(() => _price = v),
    );
  }

  Widget _typeField() {
    final showSelect = !_rangeLoading && _sizesFor(_type).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Type *'),
        const SizedBox(height: 8),
        if (!showSelect)
          _staticType()
        else
          _typeSegmented(),
      ],
    );
  }

  Widget _staticType() => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          _type.isEmpty
              ? 'Select type'
              : _type[0].toUpperCase() + _type.substring(1).toLowerCase(),
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _type.isEmpty ? Color(0xFFD1D5DB) : Color(0xFF6B7280)),
        ),
      );

  Widget _typeSegmented() => Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            for (final t in const ['gents', 'kids'])
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _type = t),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _type == t ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _type == t
                          ? const [BoxShadow(color: Colors.black12, blurRadius: 3)]
                          : null,
                    ),
                    child: Text(
                      t[0].toUpperCase() + t.substring(1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _type == t
                            ? const Color(0xFF111827)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  // ---- Step 2: Color list --------------------------------------------------------------------------------------------------------

  Widget _listStep() {
    return Column(
      children: [
        _wizardHeader(
          eyebrow: 'Step 2 of 2',
          title: 'Colors',
          onBack: () => setState(() => _step = WizardStep.common),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: _CommonBadgeEdit(
            commonType: _type,
            commonName: _name,
            commonPrice: _price,
            onEdit: () => setState(() {
              _step = WizardStep.common;
            }),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            children: [
              if (_variants.isEmpty)
                const _EmptyColors()
              else
                for (var i = 0; i < _variants.length; i++)
                  _ColorCardTile(
                    variant: _variants[i],
                    index: i + 1,
                    type: _type,
                    isOnly: _variants.length == 1,
                    onEdit: () => _startEdit(_variants[i].tempId!),
                    onDelete: () => setState(() {
                      _variants =
                          _variants.where((v) => v.tempId != _variants[i].tempId).toList();
                    }),
                  ),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _startAdd,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFFE5E7EB), width: 1.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 16, color: Color(0xFF9CA3AF)),
                      SizedBox(width: 6),
                      Text('Add New Color',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: StockFlowButton(
            label: _submitting ? 'Creating$kEllipsis' : 'Create Item',
            enabled: _variants.isNotEmpty && !_submitting,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}

Widget _wizardHeader({
  required String eyebrow,
  required String title,
  required VoidCallback onBack,
}) {
return Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    child: Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onBack,
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(Icons.arrow_back, size: 24, color: Color(0xFF9CA3AF)),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eyebrow.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500)),
            Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827))),
          ],
        ),
      ],
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)));
  }
}

class _CommonBadgeEdit extends StatelessWidget {
  const _CommonBadgeEdit(
      {required this.commonType,
      required this.commonName,
      required this.commonPrice,
      required this.onEdit});
  final String commonType;
  final String commonName;
  final String commonPrice;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(commonType.toUpperCase(),
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Color(0xFF6B7280))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commonName.isEmpty ? 'No name' : commonName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: commonName.isEmpty
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF111827)),
                ),
                const SizedBox(height: 2),
                Text(commonPrice.isEmpty ? kEmDash : '$kRupee$commonPrice',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.edit_outlined, size: 14, color: Color(0xFF9CA3AF)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyColors extends StatelessWidget {
  const _EmptyColors();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFF3F4F6),
            child: Icon(Icons.add, color: Color(0xFFD1D5DB)),
          ),
          SizedBox(height: 10),
          Text('No colors added yet',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          SizedBox(height: 2),
          Text('Tap the button below to add your first color variant',
              style: TextStyle(fontSize: 11, color: Color(0xFFE5E7EB))),
        ],
      ),
    );
  }
}

class _ColorCardTile extends StatelessWidget {
  const _ColorCardTile(
      {required this.variant,
      required this.index,
      required this.type,
      required this.isOnly,
      required this.onEdit,
      required this.onDelete});
  final ColorVariantDraft variant;
  final int index;
  final String type;
  final bool isOnly;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitle = type == 'kids' && variant.perSizeStock.isNotEmpty
        ? variant.perSizeStock.entries
            .map((e) => '${e.key}: ${e.value} pcs')
            .join(' | ')
        : '${variant.sizeRange} $kEmDash ${variant.stock} per size';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: variant.imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(variant.imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.image_outlined,
                            size: 18, color: Color(0xFFD1D5DB))),
                  )
                : const Icon(Icons.image_outlined,
                    size: 18, color: Color(0xFFD1D5DB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Variant #$index',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827))),
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF9CA3AF)),
          ),
          if (!isOnly)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFF87171)),
            ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}