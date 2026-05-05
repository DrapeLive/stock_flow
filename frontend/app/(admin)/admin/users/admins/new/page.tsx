"use client";

import { useState, useEffect } from "react";
import { adminApi } from "@/lib/api/admin";
import { brandApi } from "@/lib/api/brand";
import { toastSuccess, toastError } from "@/lib/toast";
import { Field, FieldGroup, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";
import { deriveUsername } from "@/lib/utils/deriveUsername";
import type { Business } from "@/types/auth";
import type { Brand } from "@/types/brand";

export default function NewAdminPage() {
  const router = useRouter();
  const { business, isSuperuser } = useAuth();
  const [brands, setBrands] = useState<Brand[]>([]);
  const [existingUsernames, setExistingUsernames] = useState<Set<string>>(
    new Set(),
  );
  const [formData, setFormData] = useState({
    displayName: "",
    email: "",
    password: "",
    business: isSuperuser ? "" : (business ?? ""),
    brand_id: "",
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (isSuperuser) {
      brandApi
        .getAll()
        .then(setBrands)
        .catch(() => setBrands([]));
    }
    adminApi
      .getAll()
      .then((admins) => {
        setExistingUsernames(new Set(admins.map((a) => a.username)));
      })
      .catch(() => {});
  }, [isSuperuser]);

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
    if (!formData.displayName.trim())
      newErrors.displayName = "Name is required";
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
    if (isSuperuser && !formData.business) {
      newErrors.business = "Business is required";
    }
    if (isSuperuser && !formData.brand_id) {
      newErrors.brand_id = "Brand is required";
    }
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async () => {
    if (!validate()) return;

    setIsSubmitting(true);
    try {
      const username = deriveUsername(formData.displayName, existingUsernames);
      await adminApi.create({
        username,
        display_name: formData.displayName,
        email: formData.email,
        password: formData.password,
        business: isSuperuser ? (formData.business as Business) : null,
        brand_id: parseInt(formData.brand_id),
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
        <h1 className="text-2xl font-black text-gray-900 tracking-tight">
          New Admin
        </h1>
        <p className="text-sm text-gray-400 font-medium">
          Create a new system administrator
        </p>
      </div>

      {isSuperuser ? (
        <div className="bg-amber-50 border border-amber-200 rounded-2xl px-4 py-3 mb-6 flex items-center gap-3">
          <span className="text-xs font-bold text-amber-600 uppercase tracking-wider">
            Superuser:
          </span>
          <span className="text-sm font-medium text-gray-700">
            Select a business below to create an admin for that catalog
          </span>
        </div>
      ) : (
        business && (
          <div className="bg-primary/5 border border-primary/20 rounded-2xl px-4 py-3 mb-6 flex items-center gap-3">
            <span className="text-xs font-bold text-primary uppercase tracking-wider">
              Business:
            </span>
            <span className="text-sm font-black text-gray-800 capitalize">
              {business}
            </span>
          </div>
        )
      )}

      <div className="bg-gray-50/50 border border-gray-100 rounded-3xl p-6 mb-8">
        <FieldGroup className="space-y-6 flex-1">
          <Field>
            <div className="flex justify-between items-center mb-1.5">
              <FieldLabel className="text-xs font-bold uppercase tracking-widest text-gray-400">
                Display Name
              </FieldLabel>
              {errors.displayName && (
                <span className="text-[10px] text-red-500 font-bold">
                  {errors.displayName}
                </span>
              )}
            </div>
            <Input
              placeholder="e.g. Jane Smith"
              value={formData.displayName}
              onChange={(e) => handleChange("displayName", e.target.value)}
              className={`bg-white border-gray-100 rounded-xl h-12 focus:ring-primary/10 ${errors.displayName ? "border-red-200 focus:border-red-300" : "focus:border-primary"}`}
            />
            {formData.displayName.trim() && (
              <p className="mt-1.5 text-[11px] text-gray-400">
                Username:{" "}
                <span className="font-mono font-medium text-gray-600">
                  {deriveUsername(formData.displayName, existingUsernames)}
                </span>
              </p>
            )}
          </Field>

          <Field>
            <div className="flex justify-between items-center mb-1.5">
              <FieldLabel className="text-xs font-bold uppercase tracking-widest text-gray-400">
                Email Address
              </FieldLabel>
              {errors.email && (
                <span className="text-[10px] text-red-500 font-bold">
                  {errors.email}
                </span>
              )}
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
              <FieldLabel className="text-xs font-bold uppercase tracking-widest text-gray-400">
                Secure Password
              </FieldLabel>
              {errors.password && (
                <span className="text-[10px] text-red-500 font-bold">
                  {errors.password}
                </span>
              )}
            </div>
            <Input
              type="password"
              placeholder="Minimum 6 characters"
              value={formData.password}
              onChange={(e) => handleChange("password", e.target.value)}
              className={`bg-white border-gray-100 rounded-xl h-12 focus:ring-primary/10 ${errors.password ? "border-red-200 focus:border-red-300" : "focus:border-primary"}`}
            />
          </Field>

          {isSuperuser && (
            <Field>
              <div className="flex justify-between items-center mb-1.5">
                <FieldLabel className="text-xs font-bold uppercase tracking-widest text-gray-400">
                  Business
                </FieldLabel>
                {errors.business && (
                  <span className="text-[10px] text-red-500 font-bold">
                    {errors.business}
                  </span>
                )}
              </div>
              <Select
                value={formData.business}
                onValueChange={(v) => handleChange("business", v)}
              >
                <SelectTrigger
                  className={`bg-white h-12 ${errors.business ? "border-red-200 focus:border-red-300" : "focus:border-primary"}`}
                >
                  <SelectValue placeholder="Select business" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="gents">Gents</SelectItem>
                  <SelectItem value="kids">Kids</SelectItem>
                </SelectContent>
              </Select>
            </Field>
          )}

          {isSuperuser && (
            <Field>
              <div className="flex justify-between items-center mb-1.5">
                <FieldLabel className="text-xs font-bold uppercase tracking-widest text-gray-400">
                  Brand *
                </FieldLabel>
                {errors.brand_id && (
                  <span className="text-[10px] text-red-500 font-bold">
                    {errors.brand_id}
                  </span>
                )}
              </div>
              <Select
                value={formData.brand_id}
                onValueChange={(v) => handleChange("brand_id", v)}
              >
                <SelectTrigger
                  className={`bg-white h-12 ${errors.brand_id ? "border-red-200 focus:border-red-300" : "focus:border-primary"}`}
                >
                  <SelectValue placeholder="Select brand" />
                </SelectTrigger>
                <SelectContent>
                  {brands.map((brand) => (
                    <SelectItem key={brand.id} value={String(brand.id)}>
                      {brand.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>
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
          text={isSubmitting ? "Creating..." : "Create Admin"}
          onClick={handleSubmit}
          disabled={isSubmitting}
          className="flex-2 h-14 rounded-2xl bg-primary shadow-lg shadow-primary/20 font-bold text-white active:scale-95 transition-all text-sm"
        />
      </div>
    </div>
  );
}
