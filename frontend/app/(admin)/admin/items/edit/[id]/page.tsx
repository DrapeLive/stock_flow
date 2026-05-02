"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Package, Trash2, AlertCircle, ImagePlus, X, ChevronDown } from "lucide-react";
import { Field, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import Image from "next/image";
import { ImagePreview } from "@/components/pages/ImagePreview";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { itemApi } from "@/lib/api/item";
import { updateItem, parseErrorMessage } from "@/lib/updateItem";
import { toastError } from "@/lib/toast";
import EditVariantRow from "./editVariantRow";
import CropModal from "../../new/cropModal";
import imageCompression from "browser-image-compression";
import type { EditCommonDetails, EditableVariant, ItemType } from "@/types/item";

const uid = () => Math.random().toString(36).slice(2, 9);

export default function ItemEditPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const [common, setCommon] = useState<EditCommonDetails>({
    name: "",
    description: "",
    price: "",
    type: "gents",
  });

  const [variants, setVariants] = useState<EditableVariant[]>([]);
  const [openAccordions, setOpenAccordions] = useState<string[]>([]);
  const [variantCrop, setVariantCrop] = useState<{ src: string; backendId: number } | null>(null);
  const fileRefs = useRef<Record<number, HTMLInputElement | null>>({});

  // ── Group variants by backendId ───────────────────────────────────────────

  const variantGroups = useMemo(() => {
    const groups: Record<number, {
      backendId: number;
      imageUrl: string | null;
      newImage: File | null;
      imagePreview: string | null;
      sizes: EditableVariant[];
    }> = {};

    variants.forEach((v) => {
      if (!groups[v.backendId]) {
        groups[v.backendId] = {
          backendId: v.backendId,
          imageUrl: v.imageUrl,
          newImage: v.newImage,
          imagePreview: v.imagePreview,
          sizes: [],
        };
      }
      groups[v.backendId].sizes.push(v);
    });

    return Object.values(groups);
  }, [variants]);

  // ── Variant group helpers ─────────────────────────────────────────────────

  const updateVariantGroupImage = (backendId: number, updates: Partial<EditableVariant>) => {
    setVariants((prev) =>
      prev.map((v) => (v.backendId === backendId ? { ...v, ...updates } : v))
    );
  };

  const deleteVariantGroup = (backendId: number) => {
    setVariants((prev) => prev.filter((v) => v.backendId !== backendId));
  };

  const handleVariantImageUpload = (backendId: number, e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f) return;
    setVariantCrop({ src: URL.createObjectURL(f), backendId });
    e.target.value = "";
  };

  const handleVariantCropConfirm = async (backendId: number, file: File) => {
    const compressedFile = await imageCompression(file, {
      maxSizeMB: 0.3,
      maxWidthOrHeight: 1024,
      useWebWorker: true,
    });

    updateVariantGroupImage(backendId, {
      newImage: compressedFile,
      imagePreview: URL.createObjectURL(compressedFile),
    });

    setVariantCrop(null);
  };

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
          data.variants.flatMap((v) =>
            v.sizes.map((s) => ({
              backendId: v.id,
              localId: uid(),
              size: s.size,
              stock: s.stock,
              imageUrl: v.image ?? null,
              newImage: null,
              imagePreview: null,
            })),
          ),
        );
      })
      .catch((e) => toastError("Failed to load item", e))
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
    setSaving(true);
    try {
      await updateItem(Number(id), common, variants);
      router.push("/admin/items");
    } catch (e: unknown) {
      toastError(e instanceof Error ? e.message : parseErrorMessage(e));
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
      toastError("Failed to delete item", e);
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
        <div className="relative w-20 h-20 bg-primary/10 rounded-3xl flex items-center justify-center mb-3 overflow-hidden">
          {variantGroups[0]?.imagePreview ?? variantGroups[0]?.imageUrl ? (
            <ImagePreview src={variantGroups[0].imagePreview ?? variantGroups[0].imageUrl!} alt={common.name} />
          ) : (
            <Package size={36} className="text-primary" />
          )}
        </div>
        <h2 className="text-xl font-black">{common.name || "—"}</h2>
      </div>

      <div className="space-y-4">
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
              <div className="h-12 px-3 flex items-center bg-gray-50 border border-gray-100 rounded-xl text-sm font-medium text-gray-500 capitalize">
                {common.type}
              </div>
            </Field>
          </div>
        </div>

        {/* ── Variants ── */}
        <div>
          <div className="flex items-center justify-between mb-3 px-1">
            <h2 className="font-bold text-sm">Variants</h2>
            <span className="text-[10px] text-gray-400 uppercase tracking-widest">
              {variantGroups.length} variant{variantGroups.length !== 1 ? "s" : ""}, {variants.length} size{variants.length !== 1 ? "s" : ""}
            </span>
          </div>

          {variantGroups.length === 0 && (
            <div className="flex items-center gap-2 text-amber-600 bg-amber-50 border border-amber-100 rounded-xl px-4 py-3 text-xs">
              <AlertCircle size={14} className="flex-shrink-0" />
              At least one variant is required.
            </div>
          )}

          <Accordion
            type="multiple"
            value={openAccordions}
            onValueChange={(values) => setOpenAccordions(values)}
            className="space-y-2"
          >
            {variantGroups.map((group) => {
              const currentImage = group.imagePreview ?? group.imageUrl;
              const variantLabel = group.backendId < 0 ? `New Variant` : `Variant #${group.backendId}`;
              return (
                <AccordionItem
                  key={group.backendId}
                  value={String(group.backendId)}
                  className="bg-white border border-gray-100 rounded-2xl overflow-hidden shadow-sm"
                >
                  <AccordionTrigger className="px-4 py-3 hover:no-underline [&[data-state=open]>svg]:rotate-180">
                    <div className="flex items-center gap-3 w-full">
                      {/* Variant Image */}
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          fileRefs.current[group.backendId]?.click();
                        }}
                        className="flex-shrink-0 w-10 h-10 rounded-lg overflow-hidden bg-gray-100 flex items-center justify-center group relative"
                      >
                        {currentImage ? (
                          <>
                            <Image
                              src={currentImage}
                              fill
                              className="object-cover"
                              alt=""
                              unoptimized
                            />
                            <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center">
                              <ImagePlus size={12} className="text-white opacity-0 group-hover:opacity-100 transition-opacity" />
                            </div>
                          </>
                        ) : (
                          <ImagePlus size={14} className="text-gray-300" />
                        )}
                      </button>
                      <input
                        ref={(el) => { fileRefs.current[group.backendId] = el; }}
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={(e) => handleVariantImageUpload(group.backendId, e)}
                      />

                      {/* Variant Info */}
                      <div className="flex-1 text-left">
                        <p className="text-sm font-semibold">{variantLabel}</p>
                        <p className="text-xs text-gray-400">
                          {group.sizes.length} size{group.sizes.length !== 1 ? "s" : ""}
                        </p>
                      </div>

                      {/* Remove Image */}
                      {currentImage && (
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            updateVariantGroupImage(group.backendId, {
                              newImage: null,
                              imagePreview: null,
                              imageUrl: null,
                            });
                          }}
                          className="flex-shrink-0 p-1.5 rounded-full text-gray-300 hover:text-red-400 transition-colors"
                          title="Remove image"
                        >
                          <X size={12} />
                        </button>
                      )}

                      {/* Delete Variant Group */}
                      {variantGroups.length > 1 && (
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            deleteVariantGroup(group.backendId);
                          }}
                          className="flex-shrink-0 p-1.5 rounded-full text-gray-300 hover:text-red-400 transition-colors"
                          aria-label="Delete variant"
                        >
                          <Trash2 size={14} />
                        </button>
                      )}
                    </div>
                  </AccordionTrigger>

                  <AccordionContent className="px-4 pb-3 space-y-2">
                    {group.sizes.map((v, i) => (
                      <EditVariantRow
                        key={v.localId}
                        variant={v}
                        index={i}
                        isOnly={group.sizes.length === 1}
                        onChange={(updated) => updateVariant(v.localId, updated)}
                        onDelete={() => deleteVariant(v.localId)}
                      />
                    ))}
                  </AccordionContent>
                </AccordionItem>
              );
            })}
          </Accordion>

          {/* Variant Crop Modal */}
          {variantCrop && (
            <CropModal
              src={variantCrop.src}
              onConfirm={(file) => handleVariantCropConfirm(variantCrop.backendId, file)}
              onCancel={() => setVariantCrop(null)}
            />
          )}
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
