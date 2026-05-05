import { itemApi } from "@/lib/api/item";
import { itemToFormData } from "@/lib/form-utils";
import type { CommonDetails, ColorVariant } from "@/types/item";
import { SIZE_RANGE_TO_SIZES } from "@/types/item";

export async function submitItem(
  common: CommonDetails,
  variants: ColorVariant[],
): Promise<void> {
  const variantPayload = [];

  for (const variant of variants) {
    const sizes = SIZE_RANGE_TO_SIZES[variant.sizeRange] || [];

    const sizesData = sizes.map((size) => ({
      size,
      stock: variant.stock,
    }));

    variantPayload.push({
      image: variant.image,
      sizes: sizesData,
    });
  }

  const payload = {
    name: common.name,
    price: Number(common.price),
    description: common.description || "",
    type: common.type,
    brand_id: common.brand_id,
    variants: variantPayload,
  };

  console.log(payload);

  const fd = itemToFormData(payload);
  await itemApi.create(fd);
}

// ─── Error helpers ────────────────────────────────────────────────────────────

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

/**
 * DRF error shapes:
 *   { detail: "msg" }
 *   { non_field_errors: ["msg"] }
 *   { field: ["msg"] }
 *   ["msg"]
 */
export function parseErrorMessage(body: any): string {
  if (!body) return "Something went wrong. Please try again.";
  if (typeof body === "string") return body;
  if (Array.isArray(body)) return body.join(" ");

  if (typeof body === "object") {
    const obj = body as Record<string, any>;

    if (typeof obj.detail === "string") return obj.detail;

    if (Array.isArray(obj.non_field_errors))
      return (obj.non_field_errors as string[]).join(" ");

    const messages = Object.entries(obj).flatMap(([field, val]) => {
      const msgs = Array.isArray(val) ? val : [String(val)];
      return msgs.map((m) => `${field}: ${m}`);
    });
    if (messages.length) return messages.join("\n");
  }

  return "Something went wrong. Please try again.";
}
