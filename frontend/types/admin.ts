export interface Admin {
  id: number;
  username: string;
  email: string;
}

export interface AdminRequest {
  username: string;
  email: string;
  password: string;
}

export interface AdminUpdateRequest {
  username?: string;
  email?: string;
  password?: string;
}

export type AdminAllResponse = Admin[];
export type AdminResponse = Admin;
