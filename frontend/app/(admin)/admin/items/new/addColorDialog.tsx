"use client";

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { useState, useRef, useCallback, useEffect } from "react";
import Cropper from "react-easy-crop";
import { getCroppedImg } from "@/lib/image-utils";

interface AddColorDialogProps {
  open: boolean;
  onClose: () => void;
  onAdd: (color: { name: string; image: File | null }) => void;
}

export default function AddColorDialog({
  open,
  onClose,
  onAdd,
}: AddColorDialogProps) {
  const [name, setName] = useState("");
  const [image, setImage] = useState<string | null>(null);
  const [croppedImageFile, setCroppedImageFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState(null);
  const [isCropping, setIsCropping] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (croppedImageFile) {
      const url = URL.createObjectURL(croppedImageFile);
      setPreviewUrl(url);
      return () => URL.revokeObjectURL(url);
    } else {
      setPreviewUrl(null);
    }
  }, [croppedImageFile]);

  const onCropComplete = useCallback(
    (_croppedArea: any, croppedAreaPixels: any) => {
      setCroppedAreaPixels(croppedAreaPixels);
    },
    []
  );

  const handleFile = (file: File) => {
    const reader = new FileReader();
    reader.onload = () => {
      setImage(reader.result as string);
      setIsCropping(true);
    };
    reader.readAsDataURL(file);
  };

  const handleCropSave = async () => {
    try {
      if (image && croppedAreaPixels) {
        const file = await getCroppedImg(image, croppedAreaPixels);
        setCroppedImageFile(file);
        setIsCropping(false);
      }
    } catch (e) {
      console.error(e);
    }
  };

  const handleAdd = () => {
    if (!name || !croppedImageFile) return;

    onAdd({ name, image: croppedImageFile });
    setName("");
    setImage(null);
    setCroppedImageFile(null);
    setIsCropping(false);
    onClose();
  };

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle>Add Color</DialogTitle>
        </DialogHeader>

        <div className="space-y-4 py-4">
          {!isCropping ? (
            <div
              onClick={() => fileRef.current?.click()}
              className="w-full aspect-square bg-gray-100 rounded-lg flex items-center justify-center cursor-pointer overflow-hidden relative"
            >
              {previewUrl ? (
                <img src={previewUrl} className="w-full h-full object-cover" />
              ) : (
                <span className="text-sm text-gray-400">Upload Image</span>
              )}

              <input
                hidden
                ref={fileRef}
                type="file"
                accept="image/*"
                onChange={(e) => e.target.files && handleFile(e.target.files[0])}
              />
            </div>
          ) : (
            <div className="space-y-4">
              <div className="relative w-full h-[300px] bg-gray-200 rounded-lg overflow-hidden">
                <Cropper
                  image={image!}
                  crop={crop}
                  zoom={zoom}
                  aspect={1 / 1}
                  onCropChange={setCrop}
                  onCropComplete={onCropComplete}
                  onZoomChange={setZoom}
                />
              </div>
              <div className="flex flex-col gap-2">
                <label className="text-sm font-medium">Zoom</label>
                <input
                  type="range"
                  value={zoom}
                  min={1}
                  max={3}
                  step={0.1}
                  aria-labelledby="Zoom"
                  onChange={(e) => setZoom(Number(e.target.value))}
                  className="w-full"
                />
              </div>
              <div className="flex justify-end gap-2">
                <StockFlowButton
                  variant="outline"
                  text="Cancel Crop"
                  onClick={() => setIsCropping(false)}
                />
                <StockFlowButton
                  variant="filled"
                  text="Apply Crop"
                  onClick={handleCropSave}
                />
              </div>
            </div>
          )}

          {!isCropping && (
            <Input
              placeholder="Color name"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          )}
        </div>

        {!isCropping && (
          <DialogFooter>
            <StockFlowButton variant="outline" text="Cancel" onClick={onClose} />
            <StockFlowButton
              variant="filled"
              text="Add Color"
              disabled={!name || !croppedImageFile}
              onClick={handleAdd}
            />
          </DialogFooter>
        )}
      </DialogContent>
    </Dialog>
  );
}
