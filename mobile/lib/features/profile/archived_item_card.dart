import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/text_symbols.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

/// Archived-items list card ("Archived Items" section of the profile Archives
/// tab). Mirrors `components/pages/profile/ProfilePage.tsx`.
///
/// Extracted from `profile_screen.dart` so the currency formatting and the
/// overflow-free pills row are covered by widget tests.
class ArchivedItemCard extends StatelessWidget {
  const ArchivedItemCard({
    super.key,
    required this.item,
    required this.expanded,
    required this.onToggle,
  });

  final Item item;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final thumbnail =
        item.variants.isNotEmpty ? item.variants.first.image : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onToggle,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: AppImage(thumbnail, iconSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F2937))),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (item.type != null) _typeBadge(item.type!),
                            Text(
                              formatInr(
                                  double.tryParse(item.price) ?? 0),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280)),
                            ),
                            Text('${item.totalStock} stock',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF9CA3AF))),
                            if (item.daysUntilPurge != null)
                              _purgeChip(item.daysUntilPurge!),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFFD1D5DB),
                  ),
                ],
              ),
            ),
            if (expanded)
              for (final v in item.variants) _variantRow(v),
          ],
        ),
      ),
    );
  }

  Widget _typeBadge(String type) {
    final isGents = type == 'gents';
    final fg = isGents ? const Color(0xFF0369A1) : const Color(0xFFB45309);
    final bg = isGents ? const Color(0xFFE0F2FE) : const Color(0xFFFEF3C7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(type,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg)),
    );
  }

  Widget _purgeChip(int daysUntilPurge) {
    final urgent = daysUntilPurge <= 7;
    final fg = urgent ? const Color(0xFFB45309) : const Color(0xFF6B7280);
    final bg = urgent ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        archiveCountdownLabel(daysUntilPurge),
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: fg)),
    );
  }

  Widget _variantRow(ItemVariant v) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF9FAFB))),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 34,
              height: 34,
              child: AppImage(v.image, iconSize: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final size in v.sizes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFFF3F4F6)),
                    ),
                    child: Text(
                      '${size.sizeRange} $kMiddleDot ${size.stock}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B5563)),
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