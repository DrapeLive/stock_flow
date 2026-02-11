"use client";

import { useState, useRef } from "react";
import {
  Field,
  FieldContent,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { X } from "lucide-react";
import SizesSection from "./addSizeSection";
import ColorsSection from "./addColorSection";

interface Size {
  id: string;
  label: string;
  quantity: string;
}

interface Color {
  id: string;
  name: string;
  image: string | null;
}

export default function NewItemPage() {
  const fileRef = useRef<HTMLInputElement>(null);

  const [formData, setFormData] = useState({
    name: "",
    description: "",
    type: "",
    price: "",
  });

  const [sizes, setSizes] = useState<Size[]>([]);
  const [colors, setColors] = useState<Color[]>([]);

  const [newSize, setNewSize] = useState({ label: "", quantity: "" });
  const [newColorName, setNewColorName] = useState("");
  const [newColorImage, setNewColorImage] = useState<string | null>(null);

  /* ------------------ Handlers ------------------ */

  const handleChange = (key: string, value: string) => {
    setFormData((prev) => ({ ...prev, [key]: value }));
  };

  const addSize = () => {
    if (!newSize.label || !newSize.quantity) return;

    setSizes((prev) => [...prev, { id: crypto.randomUUID(), ...newSize }]);

    setNewSize({ label: "", quantity: "" });
  };

  const removeSize = (id: string) => {
    setSizes((prev) => prev.filter((s) => s.id !== id));
  };

  const handleImageUpload = (file: File) => {
    const reader = new FileReader();
    reader.onload = () => {
      setNewColorImage(reader.result as string);
    };
    reader.readAsDataURL(file);
  };

  const addColor = () => {
    if (!newColorName) return;

    setColors((prev) => [
      ...prev,
      {
        id: crypto.randomUUID(),
        name: newColorName,
        image: newColorImage,
      },
    ]);

    setNewColorName("");
    setNewColorImage(null);
  };

  const removeColor = (id: string) => {
    setColors((prev) => prev.filter((c) => c.id !== id));
  };

  const handleSubmit = () => {
    const payload = {
      ...formData,
      sizes,
      colors,
    };

    console.log("Submitting:", payload);
    // 🔥 API integration later
  };

  /* ------------------ UI ------------------ */

  return (
    <div className="w-full px-6 py-8 flex flex-col min-h-[80vh] space-y-8">
      {/* ---------------- Item Details ---------------- */}
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
          <Input
            placeholder="Select type"
            value={formData.type}
            onChange={(e) => handleChange("type", e.target.value)}
          />
        </Field>

        <Field>
          <FieldContent>
            <FieldLabel>Price</FieldLabel>
          </FieldContent>
          <Input
            placeholder="Rs. 100"
            value={formData.price}
            onChange={(e) => handleChange("price", e.target.value)}
          />
        </Field>
      </FieldGroup>
      <SizesSection sizes={sizes} setSizes={setSizes} />

      <ColorsSection colors={colors} setColors={setColors} />
      <div className="flex justify-between items-center pt-6">
        <StockFlowButton variant="outline" text="Cancel" />
        <StockFlowButton
          variant="filled"
          text="Create new Item"
          onClick={handleSubmit}
        />
      </div>
    </div>
  );
}
