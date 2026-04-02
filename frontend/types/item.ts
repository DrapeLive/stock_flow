export type ItemType = "kids" | "gents";
export type ItemStatus = "PENDING" | "PACKED" | "DISPATCHED";

export interface ItemVariantSize {
  id: number;
  size: string;
  stock: number;
}

export interface ItemVariant {
  id: number;
  qr_code: string;
  image: string | null;
  sizes: ItemVariantSize[];
}

export interface Item {
  id: number;
  name: string;
  type?: ItemType;
  price: string;
  description?: string;
  variants: ItemVariant[];
}

export interface ItemVariantRequest {
  id?: number;
  image?: File | string | null;
  sizes: {
    size: string;
    stock?: number;
  }[];
}

export interface ItemRequest {
  name: string;
  description?: string;
  price: string;
  type?: ItemType;
  variants: ItemVariantRequest[];
}

export type ItemAllResponse = Item[];
export type ItemResponse = Item;
export type ItemQRResponse = Item & { matched_variant_id?: number };

export interface VariantSize {
  size: string;
  stock: number;
}

export interface VariantAllItem {
  id: number;
  item_id: number;
  item_name: string;
  item_type: ItemType;
  item_price: string;
  qr_code: string | null;
  image: string | null;
  sizes: VariantSize[];
  total_stock: number;
  unique_sizes: string[];
}

export type VariantAllResponse = VariantAllItem[];

export interface CommonDetails {
  name: string;
  description: string;
  price: string;
  type: ItemType;
}

export interface EditCommonDetails {
  name: string;
  description: string;
  price: string;
  type: ItemType;
}

export interface ColorVariant {
  id: string;
  sizeRange: FrontendSizeRange;
  stock: number;
  image: File | null;
  imagePreview: string | null;
}

export type FrontendSizeRange =
  | "20-36"
  | "20-38"
  | "S,M,L,XL"
  | "M,L,XL,XXL"
  | "S,M,L,XL,XXL";

export interface EditableVariant {
  backendId: number;
  localId: string;
  size: string;
  stock: number;
  imageUrl: string | null;
  newImage: File | null;
  imagePreview: string | null;
}

export const SIZES_BY_TYPE: Record<ItemType, FrontendSizeRange[]> = {
  gents: ["S,M,L,XL", "M,L,XL,XXL", "S,M,L,XL,XXL"],
  kids: ["20-36", "20-38"],
};

export const SIZE_RANGE_TO_SIZES: Record<FrontendSizeRange, string[]> = {
  "20-36": ["20-24", "26-30", "32-36"],
  "20-38": ["20-24", "26-30", "32-36", "38"],
  "S,M,L,XL": ["S", "M,L,XL"],
  "M,L,XL,XXL": ["M,L,XL", "XXL"],
  "S,M,L,XL,XXL": ["S", "M,L,XL", "XXL"],
};

export type SizeEnum = "S" | "M" | "L" | "XL" | "XXL";

export type WizardStep =
  | { screen: "common" }
  | { screen: "list" }
  | { screen: "add-color"; editingId?: string };
