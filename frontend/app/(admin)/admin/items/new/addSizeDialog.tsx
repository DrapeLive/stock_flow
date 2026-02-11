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
import { useState } from "react";

interface AddSizeDialogProps {
  open: boolean;
  onClose: () => void;
  onAdd: (size: { label: string; quantity: string }) => void;
}

export default function AddSizeDialog({
  open,
  onClose,
  onAdd,
}: AddSizeDialogProps) {
  const [label, setLabel] = useState("");
  const [quantity, setQuantity] = useState("");

  const handleAdd = () => {
    if (!label || !quantity) return;

    onAdd({ label, quantity });
    setLabel("");
    setQuantity("");
    onClose();
  };

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add Size</DialogTitle>
        </DialogHeader>

        <div className="space-y-4 py-4">
          <Input
            placeholder="Size (M)"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
          />
          <Input
            placeholder="Quantity"
            value={quantity}
            onChange={(e) => setQuantity(e.target.value)}
          />
        </div>

        <DialogFooter>
          <StockFlowButton variant="outline" text="Cancel" onClick={onClose} />
          <StockFlowButton
            variant="filled"
            text="Add Size"
            onClick={handleAdd}
          />
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
