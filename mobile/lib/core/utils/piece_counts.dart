/// Constants replicating `constants/sizes.ts` and the size-range tables from
/// `types/item.ts` (SIZE_RANGE_TO_SIZES, SIZE_RANGE_PIECE_COUNT).
library;

const List<String> kKidsSizes = [
  '20', '22', '24', '26', '28', '30', '32', '34', '36', '38',
];

const List<String> kGentsSizes = ['S', 'M', 'L', 'XL', 'XXL'];

final Map<String, List<String>> kSizeRangeToSizes = {
  '20-38': ['20-24', '26-30', '32-36', '38'],
  '20-36': ['20-24', '26-30', '32-36'],
  '26-38': ['26-30', '32-36', '38'],
  '26-36': ['26-30', '32-36'],
  '20-30': ['20-24', '26-30'],
  '32-38': ['32-36', '38'],
  '20-24': ['20-24'],
  '32-36': ['32-36'],
  '38': ['38'],
  'S,M,L,XL': ['S', 'M,L,XL'],
  'M,L,XL,XXL': ['M,L,XL', 'XXL'],
  'S,M,L,XL,XXL': ['S', 'M,L,XL', 'XXL'],
  'M,L,XL': ['M,L,XL'],
};

/// Pieces a full set occupies for a given size range.
final Map<String, int> kSizeRangePieceCount = {
  '20-38': 10,
  '20-36': 9,
  '26-38': 7,
  '20-30': 6,
  '26-36': 6,
  '32-38': 4,
  '32-36': 3,
  'S,M,L,XL,XXL': 5,
  'S,M,L,XL': 4,
  'M,L,XL,XXL': 4,
  'M,L,XL': 3,
};

/// Piece count lookup used by summaries. Unknown ranges default to 1.
int pieceCountFor(String sizeRange) => kSizeRangePieceCount[sizeRange] ?? 1;

String? singleSizeRangeFor(String size) {
  for (final entry in kSizeRangeToSizes.entries) {
    if (entry.value.length == 1 && entry.value.first == size) return entry.key;
  }
  return null;
}