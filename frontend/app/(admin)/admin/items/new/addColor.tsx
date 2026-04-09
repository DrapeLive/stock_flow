"use client";

import { useRef, useState } from "react";
import { ArrowLeft, ImagePlus, X } from "lucide-react";
import { Field, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import Image from "next/image";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import CropModal from "./cropModal";
import CommonDetailsBadge from "./commonDetailsBadge";
import {
  ColorVariant,
  CommonDetails,
  FrontendSizeRange,
} from "@/types/item";
import { SIZES_BY_TYPE } from "@/types/item";

interface Props {
  initial: ColorVariant;
  common: CommonDetails;
  isEdit: boolean;
  variantIndex: number; // for the "Variant #N" header label
  onSave: (v: ColorVariant) => void;
  onBack: () => void;
}

export default function Step2AddColor({
  initial,
  common,
  isEdit,
  variantIndex,
  onSave,
  onBack,
}: Props) {
  const [variant, setVariant] = useState<ColorVariant>(initial);
  const [cropSrc, setCropSrc] = useState<string | null>(null);
  const [stockInput, setStockInput] = useState(String(initial.stock));
  const fileRef = useRef<HTMLInputElement>(null);

  const availableSizes = SIZES_BY_TYPE[common.type];

  const set = <K extends keyof ColorVariant>(key: K, val: ColorVariant[K]) =>
    setVariant((v) => ({ ...v, [key]: val }));

  const handleFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f) return;
    setCropSrc(URL.createObjectURL(f));
    e.target.value = "";
  };

  const handleCropDone = (file: File) => {
    setVariant((v) => ({
      ...v,
      image: file,
      imagePreview: URL.createObjectURL(file),
    }));
    setCropSrc(null);
  };

  const handleStockChange = (raw: string) => {
    setStockInput(raw);
    const parsed = parseInt(raw, 10);
    set("stock", isNaN(parsed) ? 0 : parsed);
  };

  const handleStockBlur = () => {
    setStockInput(String(variant.stock));
  };

  return (
    <>
      {cropSrc && (
        <CropModal
          src={cropSrc}
          onConfirm={handleCropDone}
          onCancel={() => setCropSrc(null)}
        />
      )}

      <div className="flex flex-col min-h-screen bg-white px-4 py-8">
        {/* Header */}
        <div className="flex items-center gap-3 mb-6">
          <button
            type="button"
            onClick={onBack}
            className="p-2 -ml-2 rounded-full hover:bg-gray-50"
          >
            <ArrowLeft size={24} />
          </button>
          <div>
            <p className="text-[10px] text-gray-400 uppercase tracking-widest">
              {isEdit ? "Edit variant" : "Step 2 of 2"}
            </p>
            <h1 className="text-xl font-black leading-tight">
              Variant #{variantIndex}
            </h1>
          </div>
        </div>

        {/* Common details — read-only */}
        <CommonDetailsBadge common={common} />

        <div className="space-y-5 mt-6 flex-1">
          {/* Image */}
          <Field>
            <FieldLabel>Product Image</FieldLabel>
            <button
              type="button"
              onClick={() => fileRef.current?.click()}
              className="relative w-full rounded-2xl border-2 border-dashed border-gray-200 overflow-hidden flex items-center justify-center transition-colors hover:border-primary hover:bg-primary/5"
              style={{ height: variant.imagePreview ? 220 : 120 }}
            >
              {variant.imagePreview ? (
                <Image
                  src={variant.imagePreview}
                  fill
                  className="object-cover"
                  alt="preview"
                  unoptimized
                />
              ) : (
                <div className="flex flex-col items-center gap-2 py-8">
                  <ImagePlus size={26} className="text-gray-300" />
                  <span className="text-sm text-gray-400">
                    Tap to upload &amp; crop
                  </span>
                </div>
              )}
            </button>
            {variant.imagePreview && (
              <div className="flex gap-4 mt-2">
                <button
                  type="button"
                  onClick={() => fileRef.current?.click()}
                  className="text-xs text-primary font-medium"
                >
                  Change
                </button>
                <button
                  type="button"
                  onClick={() =>
                    setVariant((v) => ({
                      ...v,
                      image: null,
                      imagePreview: null,
                    }))
                  }
                  className="text-xs text-red-400 flex items-center gap-1"
                >
                  <X size={11} /> Remove
                </button>
              </div>
            )}
          </Field>
          <input
            ref={fileRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={handleFile}
          />

          {/* Size range — filtered by common.type */}
          <Field>
            <FieldLabel>Size Range</FieldLabel>
            <Select
              value={variant.sizeRange}
              onValueChange={(v: FrontendSizeRange) => set("sizeRange", v)}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {availableSizes.map((s) => (
                  <SelectItem key={s} value={s}>
                    {s}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>

          {/* Stock */}
          <Field>
            <FieldLabel>Stock per size</FieldLabel>
            <Input
              type="number"
              min={0}
              inputMode="numeric"
              value={stockInput}
              onChange={(e) => handleStockChange(e.target.value)}
              onBlur={handleStockBlur}
              onFocus={(e) => e.target.select()}
            />
          </Field>
        </div>

        {/* CTA */}
        <div className="mt-auto pt-8 pb-6">
          <StockFlowButton
            variant="filled"
            text={isEdit ? "Save Changes" : "Add Variant"}
            onClick={() => onSave(variant)}
            className="w-full h-14 rounded-2xl bg-primary text-white font-bold shadow-lg shadow-primary/20 flex items-center justify-center"
          />
        </div>
      </div>
    </>
  );
}
