import { itemApi } from "@/lib/api/item";
import { objectToFormData } from "@/lib/form-utils";
import type { CommonDetails, ColorVariant } from "@/types/item";
import { RANGE_TO_BACKEND } from "@/types/item";

/**
 * Builds FormData using objectToFormData which produces the key format
 * DRF's multipart parser expects: variants[0]size, variants[0]stock, etc.
 * (no bracket around the nested key — e.g. variants[0]size NOT variants[0][size])
 */
export async function submitItem(
  common: CommonDetails,
  variants: ColorVariant[],
): Promise<void> {
  const variantRows: Array<{ size: string; stock: number; image?: File }> = [];

  for (const variant of variants) {
    for (const size of RANGE_TO_BACKEND[variant.sizeRange]) {
      variantRows.push({
        size,
        stock: variant.stock,
        ...(variant.image && { image: variant.image }),
      });
    }
  }

  const payload = {
    name: common.name,
    price: common.price,
    ...(common.type && { type: common.type }),
    ...(common.description && { description: common.description }),
    variants: variantRows,
  };

  const fd = objectToFormData(payload);
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
export function parseErrorMessage(body: unknown): string {
  if (!body) return "Something went wrong. Please try again.";
  if (typeof body === "string") return body;
  if (Array.isArray(body)) return body.join(" ");

  if (typeof body === "object") {
    const obj = body as Record<string, unknown>;

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
