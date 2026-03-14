"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Package, Trash2, AlertCircle } from "lucide-react";
import { Field, FieldLabel } from "@/components/ui/field";
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
import { AlertDestructive } from "@/components/ui/AlertDestructive";
import { itemApi } from "@/lib/api/item";
import { updateItem, parseErrorMessage } from "@/lib/updateItem";
import EditVariantRow from "./editVariantRow";
import type { EditCommonDetails, EditableVariant } from "@/types/item";
import type { ItemType } from "@/types/item";

const uid = () => Math.random().toString(36).slice(2, 9);

export default function ItemEditPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [common, setCommon] = useState<EditCommonDetails>({
    name: "",
    description: "",
    price: "",
    type: "gents",
  });

  const [variants, setVariants] = useState<EditableVariant[]>([]);

  // ── Fetch ─────────────────────────────────────────────────────────────────

  useEffect(() => {
    if (!id) return;
    itemApi
      .getOne(Number(id))
      .then((data) => {
        setCommon({
          name: data.name,
          description: data.description ?? "",
          price: data.price,
          type: (data.type as ItemType) ?? "gents",
        });
        setVariants(
          data.variants.map((v) => ({
            backendId: v.id,
            localId: uid(),
            size: v.size,
            stock: v.stock ?? 0,
            imageUrl: v.image ?? null,
            newImage: null,
            imagePreview: null,
          })),
        );
      })
      .catch((e) => setError(parseErrorMessage(e)))
      .finally(() => setLoading(false));
  }, [id]);

  // ── Variant helpers ───────────────────────────────────────────────────────

  const updateVariant = (localId: string, updated: EditableVariant) =>
    setVariants((prev) =>
      prev.map((v) => (v.localId === localId ? updated : v)),
    );

  const deleteVariant = (localId: string) =>
    setVariants((prev) => prev.filter((v) => v.localId !== localId));

  // ── Save ──────────────────────────────────────────────────────────────────

  const handleSave = async () => {
    setError(null);
    setSaving(true);
    try {
      await updateItem(Number(id), common, variants);
      router.push("/admin/items");
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : parseErrorMessage(e));
    } finally {
      setSaving(false);
    }
  };

  // ── Delete ────────────────────────────────────────────────────────────────

  const handleDelete = async () => {
    if (!confirm("Delete this item? This cannot be undone.")) return;
    setDeleting(true);
    try {
      await itemApi.delete(Number(id));
      router.push("/admin/items");
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to delete item.");
      setDeleting(false);
    }
  };

  // ── Render ────────────────────────────────────────────────────────────────

  const isValid =
    common.name.trim() !== "" &&
    common.price.trim() !== "" &&
    variants.length > 0;

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <p className="text-gray-400 text-sm">Loading…</p>
      </div>
    );
  }

  return (
    <div className="w-full px-4 py-8 flex flex-col min-h-screen bg-white">
      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <button
          type="button"
          onClick={() => router.back()}
          className="p-2 -ml-2 rounded-full hover:bg-gray-50"
        >
          <ArrowLeft size={24} />
        </button>
        <div className="text-center flex-1">
          <h1 className="text-xl font-black">Edit Item</h1>
          <p className="text-[10px] text-gray-400 uppercase tracking-widest">
            ID #{id}
          </p>
        </div>
        <button
          type="button"
          onClick={handleDelete}
          disabled={deleting}
          className="p-2 rounded-xl text-red-400 hover:bg-red-50 transition-colors"
        >
          <Trash2 size={20} />
        </button>
      </div>

      {/* Avatar */}
      <div className="flex flex-col items-center mb-8">
        <div className="w-20 h-20 bg-primary/10 rounded-3xl flex items-center justify-center mb-3">
          <Package size={36} className="text-primary" />
        </div>
        <h2 className="text-xl font-black">{common.name || "—"}</h2>
      </div>

      <div className="space-y-4">
        {/* Error */}
        {error && <AlertDestructive heading="Error" description={error} />}

        {/* ── Common Details ── */}
        <div className="bg-gray-50 border border-gray-100 rounded-2xl px-5 py-5 space-y-4">
          <p className="text-[10px] text-gray-400 uppercase tracking-widest">
            Common Details
          </p>

          <Field>
            <FieldLabel>Name *</FieldLabel>
            <Input
              value={common.name}
              onChange={(e) =>
                setCommon((p) => ({ ...p, name: e.target.value }))
              }
            />
          </Field>

          <Field>
            <FieldLabel>Description</FieldLabel>
            <Textarea
              value={common.description}
              onChange={(e) =>
                setCommon((p) => ({ ...p, description: e.target.value }))
              }
            />
          </Field>

          <div className="grid grid-cols-2 gap-4">
            <Field>
              <FieldLabel>Price (₹) *</FieldLabel>
              <Input
                type="number"
                min={0}
                value={common.price}
                onChange={(e) =>
                  setCommon((p) => ({ ...p, price: e.target.value }))
                }
              />
            </Field>

            <Field>
              <FieldLabel>Type</FieldLabel>
              <Select
                value={common.type}
                onValueChange={(v: ItemType) =>
                  setCommon((p) => ({ ...p, type: v }))
                }
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
          </div>
        </div>

        {/* ── Variants ── */}
        <div>
          <div className="flex items-center justify-between mb-3 px-1">
            <h2 className="font-bold text-sm">Variants</h2>
            <span className="text-[10px] text-gray-400 uppercase tracking-widest">
              {variants.length} size{variants.length !== 1 ? "s" : ""}
            </span>
          </div>

          {variants.length === 0 && (
            <div className="flex items-center gap-2 text-amber-600 bg-amber-50 border border-amber-100 rounded-xl px-4 py-3 text-xs">
              <AlertCircle size={14} className="flex-shrink-0" />
              At least one variant is required.
            </div>
          )}

          <div className="space-y-2">
            {variants.map((v, i) => (
              <EditVariantRow
                key={v.localId}
                variant={v}
                index={i}
                isOnly={variants.length === 1}
                onChange={(updated) => updateVariant(v.localId, updated)}
                onDelete={() => deleteVariant(v.localId)}
              />
            ))}
          </div>
        </div>
      </div>

      {/* Save */}
      <div className="mt-8 mb-24">
        <StockFlowButton
          variant="filled"
          text={saving ? "Saving…" : "Save Changes"}
          disabled={!isValid || saving}
          onClick={handleSave}
          className="w-full h-14 rounded-2xl bg-primary text-white font-bold shadow-lg shadow-primary/20 flex items-center justify-center"
        />
      </div>
    </div>
  );
}
