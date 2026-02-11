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
import { useState, useRef } from "react";

interface AddColorDialogProps {
  open: boolean;
  onClose: () => void;
  onAdd: (color: { name: string; image: string | null }) => void;
}

export default function AddColorDialog({
  open,
  onClose,
  onAdd,
}: AddColorDialogProps) {
  const [name, setName] = useState("");
  const [image, setImage] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const handleFile = (file: File) => {
    const reader = new FileReader();
    reader.onload = () => setImage(reader.result as string);
    reader.readAsDataURL(file);
  };

  const handleAdd = () => {
    if (!name) return;

    onAdd({ name, image });
    setName("");
    setImage(null);
    onClose();
  };

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add Color</DialogTitle>
        </DialogHeader>

        <div className="space-y-4 py-4">
          <div
            onClick={() => fileRef.current?.click()}
            className="w-full h-32 bg-gray-100 rounded-lg flex items-center justify-center cursor-pointer overflow-hidden"
          >
            {image ? (
              <img src={image} className="h-full object-cover" />
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

          <Input
            placeholder="Color name"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </div>

        <DialogFooter>
          <StockFlowButton variant="outline" text="Cancel" onClick={onClose} />
          <StockFlowButton
            variant="filled"
            text="Add Color"
            onClick={handleAdd}
          />
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
