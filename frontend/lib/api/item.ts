import type {
    ItemAllResponse,
    ItemResponse,
    ItemRequest,
    ItemQRResponse,
    VariantAllResponse,
    ItemStockEntry,
    FrontendSizeRange,
    ItemType,
    ItemCategory,
    CustomerRequirementResponse,
} from "@/types/item";
import { api } from "./axios";

export interface SizeRangeResponse {
    item_creation_sizes_by_type: Record<ItemType, FrontendSizeRange[]>;

    order_creation_sizes_by_type: Record<ItemType, FrontendSizeRange[]>;
}

export const itemApi = {
    getCategories(): Promise<ItemCategory[]> {
        return api.get<ItemCategory[]>("/api/items/categories/").then((r) => r.data);
    },

    createCategory(name: string): Promise<ItemCategory> {
        return api.post<ItemCategory>("/api/items/categories/", { name }).then((r) => r.data);
    },

    updateCategory(id: number, name: string): Promise<ItemCategory> {
        return api.patch<ItemCategory>(`/api/items/categories/${id}/`, { name }).then((r) => r.data);
    },

    deleteCategory(id: number): Promise<void> {
        return api.delete(`/api/items/categories/${id}/`).then((r) => r.data);
    },

    getAll(): Promise<ItemAllResponse> {
        return api.get<ItemAllResponse>("/api/items/").then((r) => r.data);
    },

    getArchived(): Promise<ItemAllResponse> {
        return api
            .get<ItemAllResponse>("/api/items/archived/")
            .then((r) => r.data);
    },

    checkOutOfStock(
        qrCode: string,
        orderId?: number | null,
    ): Promise<{ out_of_stock: boolean; group_stock: boolean }> {
        const params = new URLSearchParams({
            qr_code: qrCode,
        });

        if (orderId) {
            params.append("order_id", orderId.toString());
        }

        return api
            .get<{
                out_of_stock: boolean;
                group_stock: boolean;
            }>(`/api/items/by-qr/out-of-stock/?${params.toString()}`)
            .then((r) => r.data);
    },

    getAllVariants(): Promise<VariantAllResponse> {
        return api
            .get<VariantAllResponse>("/api/items/variants/all/")
            .then((r) => r.data);
    },

    getStockList(): Promise<ItemStockEntry[]> {
        return api
            .get<ItemStockEntry[]>("/api/items/stock-list/")
            .then((r) => r.data);
    },

    getOne(id: number): Promise<ItemResponse> {
        return api.get<ItemResponse>(`/api/items/${id}/`).then((r) => r.data);
    },

    create(data: ItemRequest | FormData): Promise<ItemResponse> {
        return api
            .post<ItemResponse>("/api/items/", data)
            .then((r) => r.data);
    },

    byqr(qrCode: string, agentId?: number): Promise<ItemQRResponse> {
        const params = new URLSearchParams({ qr_code: qrCode });
        if (agentId) params.append("agent_id", String(agentId));
        return api
            .get<ItemQRResponse>(`/api/items/by-qr/?${params.toString()}`)
            .then((r) => r.data);
    },

    update(id: number, data: ItemRequest | FormData): Promise<ItemResponse> {
        return api
            .put<ItemResponse>(`/api/items/${id}/`, data)
            .then((r) => r.data);
    },

    delete(id: number, pin: string): Promise<void> {
        return api
            .delete(`/api/items/${id}/`, { data: { pin } })
            .then((r) => r.data);
    },

    getSizeRanges(): Promise<SizeRangeResponse> {
        return api
            .get<SizeRangeResponse>("/api/items/size-ranges")
            .then((r) => r.data);
    },

    createVariant: async (formData: FormData) => {
        const res = await api.post("/items/variants/", formData);
        return res.data;
    },

    getCustomerRequirements(id: number): Promise<CustomerRequirementResponse> {
        return api
            .get<CustomerRequirementResponse>(`/api/items/customer-requirements/?item_id=${id}`)
            .then((r) => r.data);
    },
};
