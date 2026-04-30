export interface Customer {
  id: number;
  total_orders: string;
  agent_name: string;
  name: string;
  address: string;
  contact: string;
  agent: number;
  has_business_orders?: boolean | null;
}

export interface CustomerCreateRequest {
  name: string;
  address: string;
  contact: string;
  agent: number;
}

export interface CustomerUpdateRequest {
  name?: string;
  address?: string;
  contact?: string;
  agent?: number;
}

export type CustomerAllResponse = Customer[];
export type CustomerResponse = Customer;
