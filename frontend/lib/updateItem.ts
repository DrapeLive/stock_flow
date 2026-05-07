import { EditableVariant, EditCommonDetails } from "@/types/item";
import { api } from "./api";
import { itemApi } from "./api/item";

export async function updateItem(
  itemId: number,
  common: EditCommonDetails,
  variants: EditableVariant[],
): Promise<void> {
  const groupedVariants = variants.reduce<
    Record<
      string,
      {
        id?: number;
        sizes: { size: string; stock: number }[];
        newImage?: File | null;
      }
    >
  >((acc, v) => {
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
      // no image here — JSON can't carry File objects
    })),
  };

  await itemApi.update(itemId, payload);

  const imageUpdates = Object.values(groupedVariants).filter(
    (g) => g.newImage && g.id, // only existing variants with a new image
  );
  if (imageUpdates.length === 0) return;

  await Promise.all(
    imageUpdates.map((g) => {
      const fd = new FormData();
      fd.append("image", g.newImage!);
      return api.patch(`/api/items/variants/${g.id}/`, fd, {
        headers: { "Content-Type": "multipart/form-data" },
      });
    }),
  );
}
