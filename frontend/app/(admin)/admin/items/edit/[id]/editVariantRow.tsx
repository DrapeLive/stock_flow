"use client";

import { useRef, useState } from "react";
import { ImagePlus, Trash2, X } from "lucide-react";
import { Input } from "@/components/ui/input";
import Image from "next/image";
import CropModal from "../../new/cropModal";
import type { EditableVariant } from "@/types/item";

interface Props {
  variant: EditableVariant;
  index: number;
  isOnly: boolean;
  onChange: (updated: EditableVariant) => void;
  onDelete: () => void;
}

export default function EditVariantRow({
  variant,
  index,
  isOnly,
  onChange,
  onDelete,
}: Props) {
  const [cropSrc, setCropSrc] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const set = <K extends keyof EditableVariant>(
    key: K,
    val: EditableVariant[K],
  ) => onChange({ ...variant, [key]: val });

  const handleFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f) return;
    setCropSrc(URL.createObjectURL(f));
    e.target.value = "";
  };

  const currentImage = variant.imagePreview ?? variant.imageUrl;

  return (
    <>
      {cropSrc && (
        <CropModal
          src={cropSrc}
          onConfirm={(file) => {
            onChange({
              ...variant,
              newImage: file,
              imagePreview: URL.createObjectURL(file),
            });
            setCropSrc(null);
          }}
          onCancel={() => setCropSrc(null)}
        />
      )}

      <div className="flex items-center gap-3 bg-white border border-gray-100 rounded-2xl px-3 py-3 shadow-sm">
        {/* Image */}
        <button
          type="button"
          onClick={() => fileRef.current?.click()}
          className="flex-shrink-0 w-12 h-12 rounded-xl overflow-hidden bg-gray-100 flex items-center justify-center group relative"
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
                <ImagePlus
                  size={14}
                  className="text-white opacity-0 group-hover:opacity-100 transition-opacity"
                />
              </div>
            </>
          ) : (
            <ImagePlus size={16} className="text-gray-300" />
          )}
        </button>
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={handleFile}
        />

        {/* Size chip */}
        <div className="flex-shrink-0 w-14 text-center">
          <span className="inline-block bg-gray-100 text-gray-600 text-xs font-bold rounded-lg px-2 py-1">
            {variant.size}
          </span>
        </div>

        {/* Stock */}
        <div className="flex-1 flex items-center gap-2">
          <span className="text-xs text-gray-400 flex-shrink-0">Stock</span>
          <Input
            type="number"
            min={0}
            value={variant.stock === 0 ? "" : variant.stock}
            placeholder="0"
            onChange={(e) => set("stock", parseInt(e.target.value, 10) || 0)}
            onFocus={(e) => e.target.select()}
            className="h-8 text-sm"
          />
        </div>

        {/* Remove image */}
        {currentImage && (
          <button
            type="button"
            onClick={() =>
              onChange({
                ...variant,
                newImage: null,
                imagePreview: null,
                imageUrl: null,
              })
            }
            className="flex-shrink-0 p-1.5 rounded-full text-gray-300 hover:text-red-400 transition-colors"
            title="Remove image"
          >
            <X size={14} />
          </button>
        )}

        {/* Delete row */}
        {!isOnly && (
          <button
            type="button"
            onClick={onDelete}
            className="flex-shrink-0 p-1.5 rounded-full text-gray-300 hover:text-red-400 transition-colors"
            aria-label="Delete variant"
          >
            <Trash2 size={15} />
          </button>
        )}
      </div>
    </>
  );
}
