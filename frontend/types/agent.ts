import type { Role } from "./auth";

export interface AgentUser {
  id: number;
  username: string;
  email: string;
  role?: Role;
}

export interface Agent {
  id: number;
  user: AgentUser;
  contact: string;
  total_customers: string;
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
