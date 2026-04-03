"use client";

import { useState } from "react";
import { adminApi } from "@/lib/api/admin";
import { toastSuccess, toastError } from "@/lib/toast";
import {
  Field,
  FieldContent,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { useRouter } from "next/navigation";

export default function NewAdminPage() {
  const router = useRouter();
  const [formData, setFormData] = useState({
    adminName: "",
    email: "",
    password: "",
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

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
    if (!formData.adminName.trim()) newErrors.adminName = "Name is required";
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
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async () => {
    if (!validate()) return;
    
    setIsSubmitting(true);
    try {
      await adminApi.create({
        username: formData.adminName,
        email: formData.email,
        password: formData.password,
      });
      toastSuccess("Admin created successfully");
      router.push("/admin/users/");
    } catch (error: any) {
      console.error("Error creating admin:", error);
      toastError("Failed to create admin", error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="w-full px-4 py-8 flex flex-col min-h-screen bg-white">
      <div className="mb-8">
        <h1 className="text-2xl font-black text-gray-900 tracking-tight">New Admin</h1>
        <p className="text-sm text-gray-400 font-medium">Create a new system administrator</p>
      </div>

      <div className="bg-gray-50/50 border border-gray-100 rounded-3xl p-6 mb-8">
        <FieldGroup className="space-y-6 flex-1">
          <Field>
            <div className="flex justify-between items-center mb-1.5">
              <FieldLabel className="text-xs font-bold uppercase tracking-widest text-gray-400">Admin Username</FieldLabel>
              {errors.adminName && <span className="text-[10px] text-red-500 font-bold">{errors.adminName}</span>}
            </div>
            <Input
              placeholder="e.g. admin_jane"
              value={formData.adminName}
              onChange={(e) => handleChange("adminName", e.target.value)}
              className={`bg-white border-gray-100 rounded-xl h-12 focus:ring-primary/10 ${errors.adminName ? "border-red-200 focus:border-red-300" : "focus:border-primary"}`}
            />
          </Field>

          <Field>
            <div className="flex justify-between items-center mb-1.5">
              <FieldLabel className="text-xs font-bold uppercase tracking-widest text-gray-400">Email Address</FieldLabel>
              {errors.email && <span className="text-[10px] text-red-500 font-bold">{errors.email}</span>}
            </div>
            <Input
              type="email"
              placeholder="admin@example.com"
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
          text={isSubmitting ? "Creating..." : "Create Admin"}
          onClick={handleSubmit}
          disabled={isSubmitting}
          className="flex-[2] h-14 rounded-2xl bg-primary shadow-lg shadow-primary/20 font-bold text-white active:scale-95 transition-all text-sm"
        />
      </div>
    </div>
  );
}
