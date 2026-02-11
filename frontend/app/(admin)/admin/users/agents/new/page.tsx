"use client";

import { useState } from "react";
import {
  Field,
  FieldContent,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";

export default function NewAgentPage() {
  const [formData, setFormData] = useState({
    agentName: "",
    email: "",
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
        {/* Customer Name */}
        <Field>
          <FieldContent>
            <FieldLabel>Agent Name</FieldLabel>
          </FieldContent>
          <Input
            placeholder="John Doe"
            value={formData.agentName}
            onChange={(e) => handleChange("agentName", e.target.value)}
          />
        </Field>

        {/* Email */}
        <Field>
          <FieldContent>
            <FieldLabel>Email</FieldLabel>
          </FieldContent>
          <Input
            placeholder="johndoe@gmail.com"
            value={formData.email}
            onChange={(e) => handleChange("email", e.target.value)}
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
