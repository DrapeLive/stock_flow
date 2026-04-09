import { api } from "@/lib/api/axios";
import { itemApi } from "@/lib/api/item";
import type { EditCommonDetails, EditableVariant } from "@/types/item";
import { parseErrorMessage } from "@/lib/submitItem";

export async function updateItem(
  itemId: number,
  common: EditCommonDetails,
  variants: EditableVariant[],
): Promise<void> {
  const groupedVariants = variants.reduce<Record<string, {
    id?: number;
    sizes: { size: string; stock: number }[];
    newImage?: File | null;
  }>>((acc, v) => {
    const key = v.backendId ? `existing_${v.backendId}` : `new_${v.localId}`;
    if (!acc[key]) {
      acc[key] = {
        id: v.backendId || undefined,
        sizes: [],
        newImage: v.newImage,
      };
    }
    acc[key].sizes.push({ size: v.size, stock: v.stock });
    return acc;
  }, {});

  const payload = {
    name: common.name,
    price: common.price,
    type: common.type,
    ...(common.description && { description: common.description }),
    variants: Object.values(groupedVariants).map((g) => ({
      id: g.id,
      sizes: g.sizes,
      ...(g.newImage && { image: g.newImage }),
    })),
  };

  await itemApi.update(itemId, payload);

  const imageUpdates = variants.filter((v) => v.newImage);
  if (imageUpdates.length === 0) return;

  await Promise.all(
    imageUpdates.map((v) => {
      const fd = new FormData();
      fd.append("image", v.newImage!);
      return api.patch(`/api/items/variants/${v.backendId}/`, fd, {
        headers: { "Content-Type": "multipart/form-data" },
      });
    }),
  );
}

export { parseErrorMessage };
