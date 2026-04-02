import type { Role } from "./auth";

export interface AgentUser {
  id: number;
  username: string;
  email: string;
  role?: Role;
}

export interface SizeRange {
  size_range: string;
  stock: number;
}

export interface AgentItemVariant {
  id: number;
  image: string | null;
  size_ranges: SizeRange[];
}

export interface AssignedItem {
  id: number;
  name: string;
  type: string;
  price: string;
  variants: AgentItemVariant[];
}

export interface Agent {
  id: number;
  user: AgentUser;
  contact: string;
  total_customers: string;
  assigned_items?: AssignedItem[];
}

export interface AgentRequest {
  username: string;
  email: string;
  password: string;
  contact: string;
}

export interface AgentUpdateRequest {
  username?: string;
  email?: string;
  password?: string;
  contact?: string;
}

export type AgentAllResponse = Agent[];
export type AgentResponse = Agent;
