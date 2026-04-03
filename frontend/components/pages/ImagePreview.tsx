"use client";

import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogPortal,
  DialogOverlay,
  DialogTitle,
} from "@/components/ui/dialog";
import { Search } from "lucide-react";

interface ImagePreviewProps {
  src: string;
  alt?: string;
}

export function ImagePreview({ src, alt = "Image" }: ImagePreviewProps) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        type="button"
        onClick={(e) => {
          e.stopPropagation();
          setOpen(true);
        }}
        className="relative cursor-pointer group"
        aria-label={`View ${alt} larger`}
      >
        <img src={src} alt={alt} className="w-full h-full object-cover" />
        <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center rounded-md">
          <Search
            size={20}
            className="text-white opacity-0 group-hover:opacity-100 transition-opacity"
          />
        </div>
      </button>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogPortal>
          <DialogOverlay className="bg-black/80" />
          <DialogTitle aria-description="Enlarged image of item" />
          <DialogContent className="bg-transparent border-none shadow-none p-0 max-w-[90vw] max-h-[90vh]">
            <img
              src={src}
              alt={alt}
              className="w-auto h-auto max-w-[90vw] max-h-[90vh] object-contain rounded-lg"
            />
          </DialogContent>
        </DialogPortal>
      </Dialog>
    </>
  );
}
