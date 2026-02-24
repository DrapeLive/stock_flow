"use client";

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { useState } from "react";

interface AddSizeDialogProps {
  open: boolean;
  onClose: () => void;
  onAdd: (size: { label: string; quantity: string }) => void;
  availableSizes: string[];
}

export default function AddSizeDialog({
  open,
  onClose,
  onAdd,
  availableSizes,
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
          <Select value={label} onValueChange={setLabel}>
            <SelectTrigger className="w-full h-9">
              <SelectValue placeholder="Select size" />
            </SelectTrigger>
            <SelectContent>
              {availableSizes.map((size) => (
                <SelectItem key={size} value={size}>
                  {size}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Input
            placeholder="Quantity"
            type="number"
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
