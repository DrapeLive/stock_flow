"use client";

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
import { ArrowLeft } from "lucide-react";
import type { CommonDetails, ItemType } from "@/types/item";

interface Props {
  value: CommonDetails;
  onChange: (v: CommonDetails) => void;
  onNext: () => void;
  onBack: () => void;
  lockType?: boolean;
}

export default function Step1CommonDetails({
  value,
  onChange,
  onNext,
  onBack,
  lockType,
}: Props) {
  const set = (key: keyof CommonDetails, val: string) =>
    onChange({ ...value, [key]: val });

  const isValid = value.name.trim() !== "" && value.price.trim() !== "";

  return (
    <div className="flex flex-col min-h-screen bg-white px-4 py-8">
      {/* Header */}
      <div className="flex items-center gap-3 mb-8">
        <button
          type="button"
          onClick={onBack}
          className="p-2 -ml-2 rounded-full hover:bg-gray-50"
        >
          <ArrowLeft size={24} />
        </button>
        <div>
          <p className="text-[10px] text-gray-400 uppercase tracking-widest">
            Step 1 of 2
          </p>
          <h1 className="text-xl font-black leading-tight">Item Details</h1>
        </div>
      </div>

      {/* Hint */}
      <p className="text-sm text-gray-400 mb-6 leading-relaxed">
        These details are shared across all color variants you&apos;ll add next.
      </p>

      <div className="space-y-5 flex-1">
        <Field>
          <FieldLabel>Name *</FieldLabel>
          <Input
            placeholder="e.g. Classic Sneaker"
            value={value.name}
            onChange={(e) => set("name", e.target.value)}
          />
        </Field>

        <Field>
          <FieldLabel>Description</FieldLabel>
          <Textarea
            placeholder="Describe the item…"
            value={value.description}
            onChange={(e) => set("description", e.target.value)}
          />
        </Field>

        <div className="grid grid-cols-2 gap-4">
          <Field>
            <FieldLabel>Price (₹) *</FieldLabel>
            <Input
              type="number"
              min={0}
              placeholder="0.00"
              value={value.price}
              onChange={(e) => set("price", e.target.value)}
            />
          </Field>

          <Field>
            <FieldLabel>Type *</FieldLabel>
            {lockType ? (
              <div className="h-12 px-3 flex items-center bg-gray-50 border border-gray-100 rounded-xl text-sm font-medium text-gray-500 capitalize">
                {value.type}
              </div>
            ) : (
              <Select
                value={value.type}
                onValueChange={(v: ItemType) => set("type", v)}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="gents">Gents</SelectItem>
                  <SelectItem value="kids">Kids</SelectItem>
                </SelectContent>
              </Select>
            )}
          </Field>
        </div>
      </div>

      {/* CTA */}
      <div className="mt-auto pt-8 pb-6">
        <StockFlowButton
          variant="filled"
          text="Next — Add Colors"
          disabled={!isValid}
          onClick={onNext}
          className="w-full h-14 rounded-2xl bg-primary text-white font-bold shadow-lg shadow-primary/20 flex items-center justify-center"
        />
      </div>
    </div>
  );
}
