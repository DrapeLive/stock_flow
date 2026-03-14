import { api } from "@/lib/api/axios";
import { itemApi } from "@/lib/api/item";
import type { EditCommonDetails, EditableVariant } from "@/types/item";
import { parseErrorMessage } from "@/lib/submitItem"; // reuse error helper

/**
 * PUT /api/items/{id}/ with JSON — same DRF nested approach as create.
 * Then PATCH /api/items/variants/{id}/ for any variant that has a new image.
 */
export async function updateItem(
  itemId: number,
  common: EditCommonDetails,
  variants: EditableVariant[],
): Promise<void> {
  const payload = {
    name: common.name,
    price: common.price,
    type: common.type,
    ...(common.description && { description: common.description }),
    variants: variants.map((v) => ({
      size: v.size,
      stock: v.stock,
    })),
  };

  await itemApi.update(itemId, payload as never);

  // Upload new images for variants that were changed
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
