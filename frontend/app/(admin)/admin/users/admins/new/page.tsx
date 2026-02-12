"use client";

import { useState } from "react";
import { adminApi } from "@/lib/api/admin";
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

  const handleChange = (key: string, value: string) => {
    setFormData((prev) => ({
      ...prev,
      [key]: value,
    }));
  };

  const handleSubmit = () => {
    const createAdmin = async () => {
      try {
        await adminApi.create({
          username: formData.adminName,
          email: formData.email,
          password: formData.password,
        });
        console.log("Admin created successfully");
        router.push("/admin/users/");
      } catch (error) {
        console.error("Error creating admin:", error);
      }
    };

    createAdmin();
  };

  return (
    <div className="w-full px-6 py-8 flex flex-col min-h-[80vh]">
      {/* Form */}
      <FieldGroup className="space-y-5 flex-1">
        {/* Admin Name */}
        <Field>
          <FieldContent>
            <FieldLabel>Admin Name</FieldLabel>
          </FieldContent>
          <Input
            placeholder="John Doe"
            value={formData.adminName}
            onChange={(e) => handleChange("adminName", e.target.value)}
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
            <FieldLabel>Password</FieldLabel>
          </FieldContent>
          <Input
            placeholder="******"
            value={formData.password}
            onChange={(e) => handleChange("password", e.target.value)}
          />
        </Field>
      </FieldGroup>

      {/* Buttons */}
      <div className="flex justify-between items-center mt-8">
        <StockFlowButton
          variant="outline"
          text="Cancel"
          onClick={() => router.back()}
        />

        <StockFlowButton
          variant="filled"
          text="Create new Admin"
          onClick={handleSubmit}
        />
      </div>
    </div>
  );
}
