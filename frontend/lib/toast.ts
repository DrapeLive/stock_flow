import { toast as sonner } from "sonner";
type ToastType = "success" | "error";
interface ToastOptions {
  title: string;
  description?: string;
}
interface ApiErrorResponse {
  response?: {
    data?: Record<string, any>;
  };
  data?: {
    detail?: string;
    message?: string;
  };
  message?: string;
}
function parseApiError(error: any): string {
  const err = error as ApiErrorResponse;
  if (err.response?.data?.error) return err.response.data.error;
  if (err.response?.data?.detail) return err.response.data.detail;
  if (err.data?.detail) return err.data.detail;
  if (err.data?.message) return err.data.message;
  if (err.message) return err.message;

  // Handle DRF field-level errors: { image: ["msg"], name: ["msg"] }
  const data = err.response?.data;
  if (data && typeof data === "object") {
    const messages = Object.entries(data)
      .flatMap(([field, val]) =>
        Array.isArray(val)
          ? val.map((m) => `${field}: ${m}`)
          : [`${field}: ${val}`],
      )
      .join(", ");
    if (messages) return messages;
  }

  if (error instanceof Error) return error.message;
  if (typeof error === "string") return error;
  return "Something went wrong";
}
function showToast(type: ToastType, { title, description }: ToastOptions) {
  const options = {
    duration: 3000,
    ...(description && { description }),
  };
  if (type === "success") {
    sonner.success(title, options);
  } else {
    sonner.error(title, options);
  }
}
export function toastSuccess(title: string, description?: string) {
  showToast("success", { title, description });
}
export function toastError(title: string, error?: any) {
  const description = error ? parseApiError(error) : undefined;
  showToast("error", { title, description });
}
export function toastErrorFromError(error: any) {
  const message = parseApiError(error);
  showToast("error", { title: message });
}
