export type ItemType = "kids" | "gents";
export type ItemStatus = "PENDING" | "PACKED" | "DISPATCHED";

export interface ItemVariant {
  id: number;
  size: string;
  qr_code: string;
  image: string | null;
  stock: number | null;
  item: number;
}

export interface ItemVariantRequest {
  size: string;
  image?: File | string | null;
  stock?: number;
}

export interface Item {
  id: number;
  variants: ItemVariant[];
  name: string;
  description?: string;
  price: string;
  type?: ItemType;
}

export interface ItemRequest {
  variants: ItemVariantRequest[];
  name: string;
  description?: string;
  price: string;
  type?: ItemType;
}

export type ItemAllResponse = Item[];
export type ItemResponse = Item;
export type ItemQRResponse = Item;

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

export type SizeEnum = "S" | "M" | "L" | "XL" | "XXL";

export type WizardStep =
  | { screen: "common" }
  | { screen: "list" }
  | { screen: "add-color"; editingId?: string };
