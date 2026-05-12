"use client";

import { useState, useCallback } from "react";
import Cropper from "react-easy-crop";
import type { Area } from "react-easy-crop";
import { X, Check, ZoomIn, ZoomOut } from "lucide-react";
import { getCroppedFile, getFitFile } from "@/lib/crop-utils";
import Image from "next/image";

interface Props {
  src: string;
  onConfirm: (file: File) => void;
  onCancel: () => void;
}

export default function CropModal({ src, onConfirm, onCancel }: Props) {
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState<Area | null>(null);
  const [fitMode, setFitMode] = useState<"crop" | "fit">("crop");

  const onCropComplete = useCallback((_: Area, pixels: Area) => {
    setCroppedAreaPixels(pixels);
  }, []);

  const handleConfirm = async () => {
    if (fitMode === "fit") {
      const file = await getFitFile(src);
      onConfirm(file);
      return;
    }
    if (!croppedAreaPixels) return;
    const file = await getCroppedFile(src, croppedAreaPixels);
    onConfirm(file);
  };

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-black overflow-hidden">
      <div className="flex items-center justify-between px-4 pt-12 pb-4 flex-shrink-0">
        <button
          type="button"
          onClick={onCancel}
          className="w-9 h-9 flex items-center justify-center rounded-full bg-white/10 text-white"
        >
          <X size={18} />
        </button>
        <div className="flex items-center gap-1 bg-white/10 rounded-full p-0.5">
          <button
            type="button"
            onClick={() => setFitMode("crop")}
            className={`px-3 py-1 rounded-full text-xs font-medium transition-colors ${
              fitMode === "crop"
                ? "bg-white text-black"
                : "text-white/60 hover:text-white"
            }`}
          >
            Crop
          </button>
          <button
            type="button"
            onClick={() => setFitMode("fit")}
            className={`px-3 py-1 rounded-full text-xs font-medium transition-colors ${
              fitMode === "fit"
                ? "bg-white text-black"
                : "text-white/60 hover:text-white"
            }`}
          >
            Show Whole Image
          </button>
        </div>
        <button
          type="button"
          onClick={handleConfirm}
          className="flex items-center gap-1.5 bg-white text-black rounded-full px-4 py-1.5 text-sm font-bold"
        >
          <Check size={14} />
          Use Photo
        </button>
      </div>
      {/* Crop area */}
      <div className="relative flex flex-1 min-h-0 justify-center items-center">
        {fitMode === "fit" ? (
          <div className="flex relative w-100 h-100">
            <div className="w-full h-full bg-white flex items-center justify-center">
              <Image src={src} alt="Preview" fill className="object-contain" />
            </div>
          </div>
        ) : (
          <Cropper
            image={src}
            crop={crop}
            zoom={zoom}
            aspect={1}
            onCropChange={setCrop}
            onZoomChange={setZoom}
            onCropComplete={onCropComplete}
            style={{ containerStyle: { background: "#000" } }}
          />
        )}
      </div>
      {fitMode === "crop" && (
        /* Zoom bar */
        <div className="flex items-center gap-3 px-6 py-5 flex-shrink-0">
          <button
            type="button"
            onClick={() => setZoom((z) => Math.max(1, +(z - 0.1).toFixed(2)))}
            className="text-white/60 active:text-white"
          >
            <ZoomOut size={18} />
          </button>
          <input
            type="range"
            min={1}
            max={3}
            step={0.05}
            value={zoom}
            onChange={(e) => setZoom(Number(e.target.value))}
            className="flex-1 accent-white h-1"
          />
          <button
            type="button"
            onClick={() => setZoom((z) => Math.min(3, +(z + 0.1).toFixed(2)))}
            className="text-white/60 active:text-white"
          >
            <ZoomIn size={18} />
          </button>
        </div>
      )}
    </div>
  );
}
