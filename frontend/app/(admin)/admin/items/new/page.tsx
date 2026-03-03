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
import { ArrowLeft } from "lucide-react";

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
    <div className="w-full px-4 py-8 flex flex-col min-h-screen bg-white">
      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <button
          onClick={() => router.back()}
          className="p-2 -ml-2 rounded-full hover:bg-gray-50"
        >
          <ArrowLeft size={24} />
        </button>

        <div className="text-center flex-1">
          <h1 className="text-xl font-black">Add New Item</h1>
          <p className="text-[10px] text-gray-400 uppercase tracking-widest">
            Create inventory item
          </p>
        </div>

        <div className="w-6" />
      </div>

      {/* Main Card */}
      <div className="bg-gray-50 border rounded-[2rem] p-6 space-y-10">
        {/* Item Details */}
        <FieldGroup className="space-y-6">
          <Field>
            <FieldLabel>Name</FieldLabel>
            <Input
              value={formData.name}
              onChange={(e) => handleChange("name", e.target.value)}
            />
          </Field>

          <Field>
            <FieldLabel>Description</FieldLabel>
            <Textarea
              value={formData.description}
              onChange={(e) => handleChange("description", e.target.value)}
            />
          </Field>

          <Field>
            <FieldLabel>Type</FieldLabel>
            <Select
              value={formData.type}
              onValueChange={(value: "gents" | "kids") => {
                handleChange("type", value);
                setSizes([]);
              }}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="gents">Gents</SelectItem>
                <SelectItem value="kids">Kids</SelectItem>
              </SelectContent>
            </Select>
          </Field>

          <Field>
            <FieldLabel>Price</FieldLabel>
            <Input
              type="number"
              value={formData.price}
              onChange={(e) => handleChange("price", e.target.value)}
            />
          </Field>
        </FieldGroup>

        {/* Sizes */}
        <SizesSection
          sizes={sizes}
          setSizes={setSizes}
          availableSizes={availableSizes}
        />

        {/* Colors */}
        <ColorsSection colors={colors} setColors={setColors} />
      </div>

      {/* Save Button */}
      <div className="mt-8 mb-20 px-4">
        <StockFlowButton
          variant="filled"
          text={loading ? "Creating..." : "Create Item"}
          disabled={!isFormValid || loading}
          onClick={handleSubmit}
          className="w-full h-14 rounded-2xl bg-primary text-white font-bold shadow-lg shadow-primary/20"
        />
      </div>
    </div>
  );
}
