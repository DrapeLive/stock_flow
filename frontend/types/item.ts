import type { components, operations } from "@/types/api";

// ─── Item ─────────────────────────────────────────────────────────────────────

export type ItemAllResponse =
  operations["items_list"]["responses"][200]["content"]["application/json"];

export type ItemResponse =
  operations["items_retrieve"]["responses"][200]["content"]["application/json"];

export type ItemRequest =
  operations["items_create"]["requestBody"]["content"]["application/json"];

// ─── Variant ──────────────────────────────────────────────────────────────────

// ItemVariant — from the variants list endpoint (items_variants_retrieve exists)
export type ItemVariant =
  operations["items_variants_retrieve"]["responses"][200]["content"]["application/json"];

export type ItemVariantRequest = components["schemas"]["ItemVariantRequest"];

// ─── Enums (derived from schema, safe to use directly) ────────────────────────

export type SizeEnum = components["schemas"]["SizeEnum"];
export type TypeEnum = components["schemas"]["TypeEnum"];

// Note: ItemSize (items_item_size_retrieve) no longer exists in the API schema.
// Size information is now embedded directly in ItemVariant as SizeEnum.

// ─── Size Enums ───────────────────────────────────────────────────────────────

export type FrontendSizeRange =
  | "20-36"
  | "20-38"
  | "S, M, L, XL"
  | "M, L, XL, XXL"
  | "S, M, L, XL, XXL";

export type BackendSize =
  | "20-24"
  | "26-30"
  | "32-36"
  | "38"
  | "S"
  | "M"
  | "L"
  | "XL"
  | "XXL";

export type ItemType = "gents" | "kids";

export const RANGE_TO_BACKEND: Record<FrontendSizeRange, BackendSize[]> = {
  "20-36": ["20-24", "26-30", "32-36"],
  "20-38": ["20-24", "26-30", "32-36", "38"],
  "S, M, L, XL": ["S", "M", "L", "XL"],
  "M, L, XL, XXL": ["M", "L", "XL", "XXL"],
  "S, M, L, XL, XXL": ["S", "M", "L", "XL", "XXL"],
};

export const SIZES_BY_TYPE: Record<ItemType, FrontendSizeRange[]> = {
  gents: ["S, M, L, XL", "M, L, XL, XXL", "S, M, L, XL, XXL"],
  kids: ["20-36", "20-38"],
};

// ─── Item Types ───────────────────────────────────────────────────────────────

export interface CommonDetails {
  name: string;
  description: string;
  price: string;
  type: ItemType;
}

export interface ColorVariant {
  id: string;
  // No color name — displayed as "Variant #N" in the list
  sizeRange: FrontendSizeRange;
  stock: number;
  image: File | null;
  imagePreview: string | null;
}

// ─── Wizard Steps ─────────────────────────────────────────────────────────────

export type WizardStep =
  | { screen: "common" }
  | { screen: "list" }
  | { screen: "add-color"; editingId?: string };

// A variant as it comes from the API — each row is one size
export interface EditableVariant {
  backendId: number; // real DB id, needed for PATCH image
  localId: string; // stable React key
  size: BackendSize;
  stock: number;
  imageUrl: string | null; // existing URL from server
  newImage: File | null; // replacement chosen by user
  imagePreview: string | null; // preview of newImage
}

export interface EditCommonDetails {
  name: string;
  description: string;
  price: string;
  type: ItemType;
}
