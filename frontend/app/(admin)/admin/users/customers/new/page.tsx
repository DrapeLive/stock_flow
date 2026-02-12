"use client";

import { useEffect, useState } from "react";
import StockFlowSelect from "@/components/ui/custom/stockFlowSelect";
import { agentApi } from "@/lib/api/agents";
import { customerApi } from "@/lib/api/customer";
import { CustomerCreateRequest } from "@/types/customer";
import {
  Field,
  FieldContent,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import StockFlowButton from "@/components/ui/custom/stockFlowButton";
import { useAuth } from "@/context/AuthContext";
import { useRouter } from "next/navigation";

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

  const { isAuthenticated } = useAuth();

  const [agents, setAgents] = useState<{ value: string; label: string }[]>([]);

  const router = useRouter();
  const [loadingAgents, setLoadingAgents] = useState(true);

  useEffect(() => {
    const fetchAgents = async () => {
      setLoadingAgents(true);
      try {
        const response = await agentApi.getAll();
        const formattedAgents = response.map((agent) => ({
          value: agent.id.toString(),
          label: agent.user.username,
        }));
        setAgents(formattedAgents);
      } catch (error) {
        console.error("Error fetching agents:", error);
      } finally {
        setLoadingAgents(false);
      }
    };

    fetchAgents();
  }, [isAuthenticated, router]);

  const handleSubmit = async () => {
    try {
      const payload: CustomerCreateRequest = {
        name: formData.customerName,
        address: formData.address,
        contact: formData.contactNumber,
        agent: parseInt(formData.agent),
      };
      await customerApi.create(payload);
      console.log("Customer created successfully");
      router.push("/admin/users/");
    } catch (error) {
      console.error("Error creating customer:", error);
    }
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
            options={agents}
            disabled={loadingAgents}
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
        <StockFlowButton
          variant="outline"
          text="Cancel"
          onClick={() => router.back()}
        />

        <StockFlowButton
          variant="filled"
          text="Create new Customer"
          onClick={handleSubmit}
        />
      </div>
    </div>
  );
}
