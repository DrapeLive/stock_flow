"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { adminApi } from "@/lib/api/admin";
import { AdminResponse, AdminRequest } from "@/types/admin";
import {
  Field,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { Trash2, ArrowLeft, ShieldAlert } from "lucide-react";

export default function AdminDetailPage() {
  const { id } = useParams();
  const router = useRouter();
  const [admin, setAdmin] = useState<AdminResponse | null>(null);
  const [formData, setFormData] = useState({
    username: "",
    email: "",
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});

  useEffect(() => {
    const fetchData = async () => {
      try {
        const numericId = parseInt(id as string, 10);
        const data = await adminApi.getOne(numericId);
        setAdmin(data);
        setFormData({
          username: data.username,
          email: data.email,
        });
      } catch (error) {
        console.error("Error fetching admin:", error);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, [id]);

  const handleChange = (key: string, value: string) => {
    setFormData(prev => ({ ...prev, [key]: value }));
    if (errors[key]) setErrors(prev => ({ ...prev, [key]: "" }));
  };

  const handleUpdate = async () => {
    setSaving(true);
    try {
      const numericId = parseInt(id as string, 10);
      await adminApi.update(numericId, {
        username: formData.username,
        email: formData.email,
      });
      router.refresh();
    } catch (error: any) {
      console.error("Error updating admin:", error);
      setErrors({ submit: "Failed to update admin." });
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (confirm("Are you sure you want to delete this administrator? This action is irreversible.")) {
      try {
        const numericId = parseInt(id as string, 10);
        await adminApi.delete(numericId);
        router.push("/admin/users/");
      } catch (error) {
        console.error("Error deleting admin:", error);
      }
    }
  };

  if (loading) return <div className="p-8 text-center text-gray-400">Loading details...</div>;
  if (!admin) return <div className="p-8 text-center text-red-400">Admin not found.</div>;

  return (
    <div className="w-full px-4 py-8 flex flex-col min-h-screen bg-white">
      <div className="flex items-center justify-between mb-8">
        <button onClick={() => router.back()} className="p-2 -ml-2 rounded-full hover:bg-gray-50 transition-colors">
          <ArrowLeft size={24} className="text-gray-900" />
        </button>
        <div className="text-center flex-1">
          <h1 className="text-xl font-black text-gray-900 tracking-tight">Admin Profile</h1>
          <p className="text-[10px] text-gray-400 font-black uppercase tracking-[0.2em]">Master Control</p>
        </div>
        <button onClick={handleDelete} className="p-2 rounded-xl text-red-500 hover:bg-red-50 transition-colors">
          <Trash2 size={20} />
        </button>
      </div>

      <div className="flex flex-col items-center mb-8">
        <div className="w-20 h-20 bg-amber-50 rounded-3xl flex items-center justify-center mb-4 shadow-sm">
          <ShieldAlert size={40} className="text-amber-500" />
        </div>
        <h2 className="text-2xl font-black text-gray-900">{admin.username}</h2>
        <span className="text-xs font-bold text-gray-400 mt-1 font-mono tracking-tighter">ADMINISTRATOR</span>
      </div>

      <div className="bg-gray-50/50 border border-gray-100 rounded-[2rem] p-6 space-y-6">
        <FieldGroup className="space-y-6">
          <Field>
            <FieldLabel className="text-[10px] font-black uppercase tracking-widest text-gray-400 mb-2 block">System username</FieldLabel>
            <Input
              value={formData.username}
              onChange={(e) => handleChange("username", e.target.value)}
              className="bg-white border-gray-100 rounded-xl h-12 font-bold"
            />
          </Field>

          <Field>
            <FieldLabel className="text-[10px] font-black uppercase tracking-widest text-gray-400 mb-2 block">Recovery Email</FieldLabel>
            <Input
              value={formData.email}
              onChange={(e) => handleChange("email", e.target.value)}
              className="bg-white border-gray-100 rounded-xl h-12 font-bold"
            />
          </Field>
        </FieldGroup>
      </div>

      <div className="mt-8 mb-20 px-4">
        <StockFlowButton
          variant="filled"
          text={saving ? "Processing..." : "Commit Update"}
          onClick={handleUpdate}
          disabled={saving}
          className="w-full h-14 rounded-2xl bg-black text-white font-bold shadow-lg shadow-black/10 flex items-center justify-center gap-2 active:scale-95 transition-all text-sm uppercase tracking-widest"
        />
      </div>
    </div>
  );
}
