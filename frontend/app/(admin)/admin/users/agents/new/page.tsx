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
import { agentApi } from "@/lib/api/agents";
import { useRouter } from "next/navigation";

export default function NewAgentPage() {
  const [formData, setFormData] = useState({
    agentName: "",
    email: "",
    contactNumber: "",
    password: "",
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const router = useRouter();

  const handleChange = (key: string, value: string) => {
    setFormData((prev) => ({
      ...prev,
      [key]: value,
    }));
    if (errors[key]) {
      setErrors((prev) => {
        const newErrors = { ...prev };
        delete newErrors[key];
        return newErrors;
      });
    }
  };

  const validate = () => {
    const newErrors: Record<string, string> = {};
    if (!formData.agentName.trim()) newErrors.agentName = "Name is required";
    if (!formData.email.trim()) {
      newErrors.email = "Email is required";
    } else if (!/\S+@\S+\.\S+/.test(formData.email)) {
      newErrors.email = "Invalid email format";
    }
    if (!formData.password.trim()) {
      newErrors.password = "Password is required";
    } else if (formData.password.length < 6) {
      newErrors.password = "Minimum 6 characters required";
    }
    if (!formData.contactNumber.trim()) {
      newErrors.contactNumber = "Contact number is required";
    }
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async () => {
    if (!validate()) return;

    setIsSubmitting(true);
    try {
      const payload = {
        username: formData.agentName,
        email: formData.email,
        contact: formData.contactNumber,
        password: formData.password,
      };
      const newAgent = await agentApi.create(payload);
      router.push(`/admin/users/agents/${newAgent.id}`);
    } catch (error: any) {
      console.error("Error creating agent:", error);
      setErrors({ submit: error.response?.data?.detail || "Failed to create agent. Username or Email might be taken." });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="w-full px-4 py-8 flex flex-col min-h-screen bg-white">
      <div className="mb-8">
        <h1 className="text-2xl font-black text-gray-900 tracking-tight">New Agent</h1>
        <p className="text-sm text-gray-400 font-medium">Create a new field agent account</p>
      </div>

      <div className="bg-gray-50/50 border border-gray-100 rounded-3xl p-6 mb-8">
        <FieldGroup className="space-y-6 flex-1">
          <Field>
            <div className="flex justify-between items-center mb-1.5">
              <FieldLabel className="text-xs font-bold uppercase tracking-widest text-gray-400">Agent Name</FieldLabel>
              {errors.agentName && <span className="text-[10px] text-red-500 font-bold">{errors.agentName}</span>}
            </div>
            <Input
              placeholder="e.g. John Doe"
              value={formData.agentName}
              onChange={(e) => handleChange("agentName", e.target.value)}
              className={`bg-white border-gray-100 rounded-xl h-12 focus:ring-primary/10 ${errors.agentName ? "border-red-200 focus:border-red-300" : "focus:border-primary"}`}
            />
          </Field>

          <Field>
            <div className="flex justify-between items-center mb-1.5">
              <FieldLabel className="text-xs font-bold uppercase tracking-widest text-gray-400">Email Address</FieldLabel>
              {errors.email && <span className="text-[10px] text-red-500 font-bold">{errors.email}</span>}
            </div>
            <Input
              type="email"
              placeholder="agent@example.com"
              value={formData.email}
              onChange={(e) => handleChange("email", e.target.value)}
              className={`bg-white border-gray-100 rounded-xl h-12 focus:ring-primary/10 ${errors.email ? "border-red-200 focus:border-red-300" : "focus:border-primary"}`}
            />
          </Field>

          <Field>
            <div className="flex justify-between items-center mb-1.5">
              <FieldLabel className="text-xs font-bold uppercase tracking-widest text-gray-400">Secure Password</FieldLabel>
              {errors.password && <span className="text-[10px] text-red-500 font-bold">{errors.password}</span>}
            </div>
            <Input
              type="password"
              placeholder="Minimum 6 characters"
              value={formData.password}
              onChange={(e) => handleChange("password", e.target.value)}
              className={`bg-white border-gray-100 rounded-xl h-12 focus:ring-primary/10 ${errors.password ? "border-red-200 focus:border-red-300" : "focus:border-primary"}`}
            />
          </Field>

          <Field>
            <div className="flex justify-between items-center mb-1.5">
              <FieldLabel className="text-xs font-bold uppercase tracking-widest text-gray-400">Contact detail</FieldLabel>
              {errors.contactNumber && <span className="text-[10px] text-red-500 font-bold">{errors.contactNumber}</span>}
            </div>
            <Input
              placeholder="+91 xxxxx xxxxx"
              value={formData.contactNumber}
              onChange={(e) => handleChange("contactNumber", e.target.value)}
              className={`bg-white border-gray-100 rounded-xl h-12 focus:ring-primary/10 ${errors.contactNumber ? "border-red-200 focus:border-red-300" : "focus:border-primary"}`}
            />
          </Field>

          {errors.submit && (
            <div className="p-3 bg-red-50 border border-red-100 rounded-xl text-red-600 text-xs font-bold text-center">
              {errors.submit}
            </div>
          )}
        </FieldGroup>
      </div>

      <div className="flex gap-4 items-center mt-auto pb-10">
        <StockFlowButton
          variant="outline"
          text="Cancel"
          onClick={() => router.back()}
          className="flex-1 h-14 rounded-2xl border-gray-200 font-bold text-gray-500 active:scale-95 transition-all text-sm"
        />

        <StockFlowButton
          variant="filled"
          text={isSubmitting ? "Creating..." : "Create Agent"}
          onClick={handleSubmit}
          disabled={isSubmitting}
          className="flex-[2] h-14 rounded-2xl bg-primary shadow-lg shadow-primary/20 font-bold text-white active:scale-95 transition-all text-sm"
        />
      </div>
    </div>
  );
}
