import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/piece_counts.dart';
import '../../core/utils/text_symbols.dart';
import '../../shared/widgets.dart';

/// The wizard/add-color form's draft variant. Mirrors web `ColorVariant`.
class ColorVariantDraft {
  ColorVariantDraft({
    this.tempId,
    this.sizeRange = 'S,M,L,XL',
    this.stock = 0,
    Map<String, int>? perSizeStock,
    this.displayOrder,
    this.imagePath,
  }) : perSizeStock = perSizeStock ?? const {};

  final String? tempId;
  String sizeRange;
  int stock;
  Map<String, int> perSizeStock;
  String? displayOrder;
  String? imagePath;

  ColorVariantDraft copyWith({
    String? tempId,
    String? sizeRange,
    int? stock,
    Map<String, int>? perSizeStock,
    String? displayOrder,
    String? imagePath,
  }) =>
      ColorVariantDraft(
        tempId: tempId ?? this.tempId,
        sizeRange: sizeRange ?? this.sizeRange,
        stock: stock ?? this.stock,
        perSizeStock: perSizeStock ?? this.perSizeStock,
        displayOrder: displayOrder ?? this.displayOrder,
        imagePath: imagePath ?? this.imagePath,
      );
}

/// Per-size rows submitted for a variant - the flattened version of a
/// [ColorVariantDraft] (multipart-friendly so it can build
/// `variants[N]sizes[M]size|stock`).
List<({String size, int stock})> flattenVariantSizes(
  ColorVariantDraft variant,
  String type,
) {
  if (type == 'kids') {
    final pairs = <({String size, int stock})>[];
    variant.perSizeStock.forEach((range, stock) {
      final backendSizes = kSizeRangeToSizes[range] ?? [range];
      for (final size in backendSizes) {
        pairs.add((size: size, stock: stock));
      }
    });
    return pairs;
  }
  final sizes = kSizeRangeToSizes[variant.sizeRange] ?? [];
  return sizes.map((size) => (size: size, stock: variant.stock)).toList();
}

/// Full-screen step for adding/editing one color variant.
/// Mirrors `app/(admin)/admin/items/new/addColor.tsx`.
class VariantEditorScreen extends StatefulWidget {
  const VariantEditorScreen({
    super.key,
    required this.commonName,
    required this.commonPrice,
    required this.commonType,
    required this.itemSizes,
    required this.initial,
    required this.isEdit,
    required this.variantIndex,
    required this.onSave,
    required this.onBack,
  });

  final String commonName;
  final String commonPrice;
  final String commonType;
  final List<String> itemSizes;
  final ColorVariantDraft initial;
  final bool isEdit;
  final int variantIndex;
  final void Function(ColorVariantDraft) onSave;
  final VoidCallback onBack;

  @override
  State<VariantEditorScreen> createState() => _VariantEditorScreenState();
}

class _VariantEditorScreenState extends State<VariantEditorScreen> {
  late ColorVariantDraft _variant;
  late TextEditingController _stockController;

  @override
  void initState() {
    super.initState();
    _variant = widget.initial;
    if (widget.commonType == 'kids') {
      final fullyInitialized = <String, int>{
        for (final size in widget.itemSizes) size: _variant.perSizeStock[size] ?? 0,
      };
      _variant = _variant.copyWith(perSizeStock: fullyInitialized);
    }
    _stockController =
        TextEditingController(text: widget.initial.stock.toString());
  }

  @override
  void dispose() {
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _variant = _variant.copyWith(imagePath: picked.path);
    });
  }

  void _updateStock(String raw) {
    final parsed = int.tryParse(raw);
    _variant = _variant.copyWith(stock: parsed ?? 0);
  }

  void _updatePerSizeStock(String range, String raw) {
    final parsed = int.tryParse(raw) ?? 0;
    final map = {..._variant.perSizeStock, range: parsed};
    _variant = _variant.copyWith(perSizeStock: map);
  }

  @override
  Widget build(BuildContext context) {
return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: widget.onBack,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.arrow_back,
                          size: 24, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEdit ? 'Edit variant' : 'Step 2 of 2',
                        style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Variant #${widget.variantIndex}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _CommonBadge(
                commonType: widget.commonType,
                commonName: widget.commonName,
                commonPrice: widget.commonPrice,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                children: [
                  _ImageField(
                    imagePath: _variant.imagePath,
                    onPick: _pickImage,
                    onRemove: () => setState(
                        () => _variant = _variant.copyWith(imagePath: null)),
                  ),
                  const SizedBox(height: 20),
                  if (widget.commonType == 'kids')
                    ..._kidsRows()
                  else ...[
                    _FieldLabel('Size Range'),
                    const SizedBox(height: 6),
                    _selectInput(
                      value: _variant.sizeRange,
                      items: widget.itemSizes,
                      onChanged: (v) => setState(() {
                        _variant = _variant.copyWith(sizeRange: v);
                      }),
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel('Stock per size'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      onChanged: _updateStock,
                      decoration: _inputDecoration(hint: '0'),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: StockFlowButton(
                label: widget.isEdit ? 'Save Changes' : 'Add Variant',
                onPressed: () {
                  final order = widget.variantIndex.toString();
                  widget.onSave(_variant.copyWith(
                    displayOrder:
                        _variant.displayOrder ?? order,
                  ));
                },
              ),
            ),
],
      ),
      ),
    );
  }

  List<Widget> _kidsRows() => [
        _FieldLabel('Sizes & Stock'),
        const SizedBox(height: 6),
        for (final size in widget.itemSizes)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(size,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                  ),
                  const Spacer(),
                  const Text('Stock',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  const SizedBox(width: 8),
SizedBox(
                    width: 72,
                    child: StockFlowTextField(
                      initialText: '${_variant.perSizeStock[size] ?? 0}',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      hint: '0',
                      onChanged: (raw) => _updatePerSizeStock(size, raw),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ];
}

Widget _selectInput({
  required String value,
  required List<String> items,
  required ValueChanged<String> onChanged,
}) {
  return SizedBox(
    height: 48,
    child: DropdownButtonFormField<String>(
      value: value,
      items: [for (final s in items) DropdownMenuItem(value: s, child: Text(s))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      decoration: _inputDecoration(hint: value),
      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
    ),
  );
}

InputDecoration _inputDecoration({required String hint}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
      ),
    );

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

class _CommonBadge extends StatelessWidget {
  const _CommonBadge(
      {required this.commonType,
      required this.commonName,
      required this.commonPrice});
  final String commonType;
  final String commonName;
  final String commonPrice;

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
                      color:
                          commonName.isEmpty ? const Color(0xFFD1D5DB) : const Color(0xFF111827)),
                ),
                const SizedBox(height: 2),
                Text(commonPrice.isEmpty ? kEmDash : '$kRupee$commonPrice',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageField extends StatelessWidget {
  const _ImageField(
      {required this.imagePath, required this.onPick, required this.onRemove});
  final String? imagePath;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Product Image'),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPick,
          child: Container(
            height: hasImage ? 220 : 110,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFE5E7EB), width: 1.4),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(File(imagePath!),
                        fit: BoxFit.cover, errorBuilder: (c, e, st) => const Icon(
                            Icons.image_outlined,
                            size: 26,
                            color: Color(0xFFD1D5DB))),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 26, color: Color(0xFFD1D5DB)),
                      SizedBox(height: 6),
                      Text('Tap to upload & crop',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF9CA3AF))),
                    ],
                  ),
          ),
        ),
        if (hasImage)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                TextButton(onPressed: onPick, child: const Text('Change',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500))),
                const SizedBox(width: 16),
                TextButton(onPressed: onRemove, child: const Text('Remove',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFF87171),
                        fontWeight: FontWeight.w500))),
              ],
            ),
          ),
      ],
    );
  }
}