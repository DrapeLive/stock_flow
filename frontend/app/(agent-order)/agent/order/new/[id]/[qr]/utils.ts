import type { ItemType } from "@/types/item";
import {
  SIZE_RANGE_TO_SIZES,
  FrontendSizeRange,
  SIZE_RANGE_PIECE_COUNT,
  getSizesForItemType,
} from "@/types/item";

export function getStockForSizeGroup(
  variant: { sizes: { size: string; stock: number }[] } | null,
  sizeGroup: string | null,
): number {
  if (!variant || !sizeGroup) return 0;

  const sizesInGroup =
    SIZE_RANGE_TO_SIZES[sizeGroup as FrontendSizeRange] || [];

  const sizeSet = new Set(sizesInGroup);

  const relevantStocks = variant.sizes
    .filter((s) => sizeSet.has(s.size))
    .map((s) => s.stock);

  if (relevantStocks.length === 0) return 0;

  return Math.min(...relevantStocks);
}

export function getAvailableStockForSizeGroup(
  variant: { sizes: { size: string; stock: number }[] } | null,
  sizeGroup: string | null,
  reservedItems: Array<{ size_group: string; quantity: number }>,
): number {
  if (!variant || !sizeGroup) return 0;

  const selectedSizes = SIZE_RANGE_TO_SIZES[sizeGroup as FrontendSizeRange] || [];
  if (selectedSizes.length === 0) return 0;

  const remainingStocks = selectedSizes.map((selectedSize) => {
    const baseStock = variant.sizes.find((s) => s.size === selectedSize)?.stock || 0;

    const reservedForThisSize = reservedItems.reduce((sum, item) => {
      const itemSizes = SIZE_RANGE_TO_SIZES[item.size_group as FrontendSizeRange] || [];
      if (itemSizes.includes(selectedSize)) {
        return sum + item.quantity;
      }
      return sum;
    }, 0);

    return baseStock - reservedForThisSize;
  });

  return Math.max(0, Math.min(...remainingStocks));
}

export function getPiecesForGroup(sizeGroup: string | null): number {
  if (!sizeGroup) return 0;
  return SIZE_RANGE_PIECE_COUNT[sizeGroup] || 0;
}

export function getAvailableSizeRanges(
  variant: { sizes: { size: string }[] } | null,
  type: ItemType | undefined,
): string[] {
  if (!variant || !type) return [];

  const variantSizes = Array.from(new Set(variant.sizes.map((s) => s.size)));
  const variantSizeSet = new Set(variantSizes);

  const availableRanges = getSizesForItemType(type, "order_creation");

  if (type === "gents") {
    for (const range of availableRanges) {
      const rangeSizes = SIZE_RANGE_TO_SIZES[range];
      const rangeSizeSet = new Set(rangeSizes);

      if (
        rangeSizeSet.size === variantSizeSet.size &&
        [...rangeSizeSet].every((s) => variantSizeSet.has(s))
      ) {
        return [range];
      }
    }

    return variantSizes;
  }

  return availableRanges.filter((range) => {
    const requiredSizes = SIZE_RANGE_TO_SIZES[range];
    return requiredSizes.every((s) => variantSizeSet.has(s));
  });
}

export function getMaxSizeGroup(sizeGroups: string[]): string | null {
  if (sizeGroups.length === 0) return null;
  if (sizeGroups.length === 1) return sizeGroups[0];

  return sizeGroups.reduce((max, current) => {
    const maxSizes = SIZE_RANGE_TO_SIZES[max as FrontendSizeRange]?.length || 0;
    const currentSizes =
      SIZE_RANGE_TO_SIZES[current as FrontendSizeRange]?.length || 0;
    return currentSizes > maxSizes ? current : max;
  });
}