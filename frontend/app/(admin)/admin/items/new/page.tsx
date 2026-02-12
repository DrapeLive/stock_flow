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
import { itemApi } from "@/lib/api/item";
import SizesSection from "./addSizeSection";
import ColorsSection from "./addColorSection";
import { ItemRequest } from "@/types/item";
import { useRouter } from "next/navigation";

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

interface ItemFormData {
  name: ItemRequest["name"];
  description: ItemRequest["description"];
  type: ItemRequest["type"];
  price: ItemRequest["price"];
}

export default function NewItemPage() {
  const router = useRouter();

  const fileRef = useRef<HTMLInputElement>(null);

  const [formData, setFormData] = useState<ItemFormData>({
    name: "",
    description: "",
    type: "gents",
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
    const createItem = async () => {
      try {
        const response = await itemApi.create({
          name: formData.name,
          description: formData.description,
          type: formData.type,
          price: formData.price,
          sizes: sizes.map((size) => ({
            size: size.label,
            stock: parseInt(size.quantity, 10),
          })),
          variants: colors.map((color) => ({
            color: color.name,
            image:
              "https://unsplash.com/photos/black-crew-neck-t-shirt-6Nub980bI3I",
          })),
        });
        console.log("Item created successfully:", response);
        router.push("/admin/items");
      } catch (error) {
        console.error("Error creating item:", error);
        // Optionally, show an error message to the user
      }
    };

    createItem();
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
        <StockFlowButton
          variant="outline"
          text="Cancel"
          onClick={() => router.back()}
        />
        <StockFlowButton
          variant="filled"
          text="Create new Item"
          onClick={handleSubmit}
        />
      </div>
    </div>
  );
}
