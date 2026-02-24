"use client";

import { useState } from "react";
import {
  Field,
  FieldContent,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { itemApi } from "@/lib/api/item";
import SizesSection from "./addSizeSection";
import ColorsSection from "./addColorSection";
import { ItemRequest } from "@/types/item";
import { useRouter } from "next/navigation";
import { KIDS_SIZES, GENTS_SIZES } from "@/constants/sizes";
import { itemToFormData } from "@/lib/form-utils";

interface Size {
  id: string;
  label: string;
  quantity: string;
}

interface Color {
  id: string;
  name: string;
  image: File | null;
}

interface ItemFormData {
  name: string;
  description: string;
  type: "gents" | "kids";
  price: string;
}

export default function NewItemPage() {
  const router = useRouter();

  const [formData, setFormData] = useState<ItemFormData>({
    name: "",
    description: "",
    type: "gents",
    price: "",
  });

  const [sizes, setSizes] = useState<Size[]>([]);
  const [colors, setColors] = useState<Color[]>([]);
  const [loading, setLoading] = useState(false);

  const availableSizes = formData.type === "kids" ? KIDS_SIZES : GENTS_SIZES;

  /* ------------------ Handlers ------------------ */

  const handleChange = (key: string, value: string) => {
    setFormData((prev) => ({ ...prev, [key]: value }));
  };

  const isFormValid =
    formData.name.trim() !== "" &&
    formData.description.trim() !== "" &&
    formData.price.trim() !== "" &&
    sizes.length > 0 &&
    colors.length > 0;

  const handleSubmit = async () => {
    if (!isFormValid) return;

    setLoading(true);
    try {
      const payload = {
        name: formData.name,
        description: formData.description,
        type: formData.type,
        price: formData.price,
        sizes: sizes.map((s) => ({
          size: s.label,
          stock: parseInt(s.quantity, 10),
        })),
        variants: colors.map((c) => ({
          color: c.name,
          image: c.image,
        })),
      };

      const formDataPayload = itemToFormData(payload);
      const response = await itemApi.create(formDataPayload);
      console.log("Item created successfully:", response);
      router.push("/admin/items");
    } catch (error) {
      console.error("Error creating item:", error);
    } finally {
      setLoading(false);
    }
  };

  /* ------------------ UI ------------------ */

  return (
    <div className="w-full px-6 py-8 pb-32 flex flex-col min-h-[80vh] space-y-10">
      {/* ---------------- Item Details ---------------- */}
      <div className="space-y-6">
        <h2 className="text-xl font-semibold border-b pb-2">Add item details</h2>
        <FieldGroup className="space-y-5">
          <Field>
            <FieldContent>
              <FieldLabel>Item Name</FieldLabel>
            </FieldContent>
            <Input
              placeholder="Jeans"
              value={formData.name}
              onChange={(e) => handleChange("name", e.target.value)}
            />
          </Field>

          <Field>
            <FieldContent>
              <FieldLabel>Description</FieldLabel>
            </FieldContent>
            <Textarea
              placeholder="Item description"
              value={formData.description}
              onChange={(e) => handleChange("description", e.target.value)}
            />
          </Field>

          <Field>
            <FieldContent>
              <FieldLabel>Type</FieldLabel>
            </FieldContent>
            <Select
              value={formData.type}
              onValueChange={(value: "gents" | "kids") => {
                handleChange("type", value);
                setSizes([]); // Reset sizes when type changes
              }}
            >
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Select type" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="gents">Gents</SelectItem>
                <SelectItem value="kids">Kids</SelectItem>
              </SelectContent>
            </Select>
          </Field>

          <Field>
            <FieldContent>
              <FieldLabel>Price</FieldLabel>
            </FieldContent>
            <Input
              placeholder="Rs. 100"
              type="number"
              value={formData.price}
              onChange={(e) => handleChange("price", e.target.value)}
            />
          </Field>
        </FieldGroup>
      </div>

      {/* ---------------- Inventory (Sizes) ---------------- */}
      <div className="space-y-6">
        <h2 className="text-xl font-semibold border-b pb-2">Inventory (Sizes)</h2>
        <SizesSection
          sizes={sizes}
          setSizes={setSizes}
          availableSizes={availableSizes}
        />
      </div>

      {/* ---------------- Variants (Colors) ---------------- */}
      <div className="space-y-6">
        <h2 className="text-xl font-semibold border-b pb-2">Variants (Colors)</h2>
        <ColorsSection colors={colors} setColors={setColors} />
      </div>

      {/* ---------------- Actions ---------------- */}
      <div className="flex justify-between items-center pt-6">
        <StockFlowButton
          variant="outline"
          text="Cancel"
          onClick={() => router.back()}
        />
        <StockFlowButton
          variant="filled"
          text={loading ? "Creating..." : "Create new Item"}
          disabled={!isFormValid || loading}
          onClick={handleSubmit}
        />
      </div>
    </div>
  );
}
