"use client";

import { useState } from "react";
import StockFlowSelect from "@/components/ui/custom/stockFlowSelect";
import {
  Field,
  FieldContent,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";

export default function NewCustomerPage() {
  const [formData, setFormData] = useState({
    agent: "",
    customerName: "",
    address: "",
    contactNumber: "",
  });

  const handleChange = (key: string, value: string) => {
    setFormData((prev) => ({
      ...prev,
      [key]: value,
    }));
  };

  const handleSubmit = () => {
    console.log("Submitting:", formData);
    // 🔥 API integration later
  };

  return (
    <div className="w-full px-6 py-8 flex flex-col min-h-[80vh]">
      {/* Form */}
      <FieldGroup className="space-y-5 flex-1">
        {/* Agent */}
        <Field>
          <FieldContent>
            <FieldLabel>Agent</FieldLabel>
          </FieldContent>
          <StockFlowSelect
            value={formData.agent}
            onChange={(val) => handleChange("agent", val)}
          />
        </Field>

        {/* Customer Name */}
        <Field>
          <FieldContent>
            <FieldLabel>Customer Name</FieldLabel>
          </FieldContent>
          <Input
            placeholder="Fashion Hub"
            value={formData.customerName}
            onChange={(e) => handleChange("customerName", e.target.value)}
          />
        </Field>

        {/* Address */}
        <Field>
          <FieldContent>
            <FieldLabel>Address</FieldLabel>
          </FieldContent>
          <Textarea
            rows={3}
            placeholder="Kollengode, Palakkad, Kerala"
            value={formData.address}
            onChange={(e) => handleChange("address", e.target.value)}
          />
        </Field>

        {/* Contact Number */}
        <Field>
          <FieldContent>
            <FieldLabel>Contact Number</FieldLabel>
          </FieldContent>
          <Input
            placeholder="+91 99xxxxxxx"
            value={formData.contactNumber}
            onChange={(e) => handleChange("contactNumber", e.target.value)}
          />
        </Field>
      </FieldGroup>

      {/* Buttons */}
      <div className="flex justify-between items-center mt-8">
        <StockFlowButton variant="outline" text="Cancel" />

        <StockFlowButton variant="filled" text="Create new Customer" />
      </div>
    </div>
  );
}
