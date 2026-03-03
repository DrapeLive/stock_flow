"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { itemApi } from "@/lib/api/item";
import { ItemResponse } from "@/types/item";
import { Field, FieldGroup, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import SizesSection from "../../new/addSizeSection";
import ColorsSection from "../../new/addColorSection";
import { KIDS_SIZES, GENTS_SIZES } from "@/constants/sizes";
import { itemToFormData } from "@/lib/form-utils";
import { Trash2, ArrowLeft, Package } from "lucide-react";

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

export default function ItemDetailPage() {
  const { id } = useParams();
  const router = useRouter();

  const [item, setItem] = useState<ItemResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const [formData, setFormData] = useState({
    name: "",
    description: "",
    type: "gents" as "gents" | "kids",
    price: "",
  });

  const [sizes, setSizes] = useState<Size[]>([]);
  const [colors, setColors] = useState<Color[]>([]);

  const availableSizes = formData.type === "kids" ? KIDS_SIZES : GENTS_SIZES;

  /* ---------------- Fetch Item ---------------- */

  useEffect(() => {
    const fetchItem = async () => {
      try {
        const data = await itemApi.getOne(Number(id));
        setItem(data);

        setFormData({
          name: data.name,
          description: data.description || "",
          type: (data.type as "gents" | "kids") || "gents",
          price: data.price,
        });

        // Prefill sizes
        setSizes(
          data.sizes.map((s, index) => ({
            id: `${index}`,
            label: s.size,
            quantity: String(s.stock),
          })),
        );

        // Prefill colors
        setColors(
          data.variants.map((v, index) => ({
            id: `${index}`,
            name: v.color,
            image: null, // existing image stays unless replaced
          })),
        );
      } catch (error) {
        console.error("Error fetching item:", error);
      } finally {
        setLoading(false);
      }
    };

    if (id) fetchItem();
  }, [id]);

  /* ---------------- Handlers ---------------- */

  const handleChange = (key: string, value: string) => {
    setFormData((prev) => ({ ...prev, [key]: value }));
  };

  const isFormValid =
    formData.name.trim() !== "" &&
    formData.description.trim() !== "" &&
    formData.price.trim() !== "" &&
    sizes.length > 0 &&
    colors.length > 0;

  const handleUpdate = async () => {
    if (!isFormValid || !item) return;

    setSaving(true);

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
          image: c.image, // only sent if replaced
        })),
      };

      const formDataPayload = itemToFormData(payload);

      await itemApi.update(Number(id), formDataPayload);

      router.refresh();
    } catch (error) {
      console.error("Error updating item:", error);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!confirm("Are you sure you want to delete this item?")) return;

    try {
      await itemApi.delete(Number(id));
      router.push("/admin/items");
    } catch (error) {
      console.error("Error deleting item:", error);
    }
  };

  /* ---------------- UI ---------------- */

  if (loading)
    return (
      <div className="p-8 text-center text-gray-400">Loading details...</div>
    );

  if (!item)
    return <div className="p-8 text-center text-red-400">Item not found.</div>;

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
          <h1 className="text-xl font-black">Item Profile</h1>
          <p className="text-[10px] text-gray-400 uppercase tracking-widest">
            Manage item details
          </p>
        </div>

        <button
          onClick={handleDelete}
          className="p-2 rounded-xl text-red-500 hover:bg-red-50"
        >
          <Trash2 size={20} />
        </button>
      </div>

      {/* Icon Section */}
      <div className="flex flex-col items-center mb-8">
        <div className="w-20 h-20 bg-primary/10 rounded-3xl flex items-center justify-center mb-4">
          <Package size={40} className="text-primary" />
        </div>
        <h2 className="text-2xl font-black">{formData.name}</h2>
        <span className="text-xs font-bold text-gray-400 mt-1">ID: #{id}</span>
      </div>

      {/* Main Card */}
      <div className="bg-gray-50 border rounded-[2rem] p-6 space-y-10">
        {/* Basic Details */}
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
            <select
              value={formData.type}
              onChange={(e) => {
                handleChange("type", e.target.value);
                setSizes([]);
              }}
              className="w-full border rounded-lg p-2"
            >
              <option value="gents">Gents</option>
              <option value="kids">Kids</option>
            </select>
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
          text={saving ? "Saving..." : "Save Changes"}
          disabled={!isFormValid || saving}
          onClick={handleUpdate}
          className="w-full h-14 rounded-2xl"
        />
      </div>
    </div>
  );
}
