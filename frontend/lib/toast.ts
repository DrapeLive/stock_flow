import { toast as sonner } from "sonner";

type ToastType = "success" | "error";
interface ToastOptions {
  title: string;
  description?: string;
}

function parseApiError(error: any): string {
  try {
    // Axios-style response
    const data = error?.response?.data;

    if (data) {
      // Django sent HTML (e.g. 500 debug page)
      if (typeof data === "string") {
        return data.includes("<html") ? "Server error, please try again" : data;
      }

      if (typeof data === "object") {
        // { error: "..." } or { detail: "..." }
        if (typeof data.error === "string") return data.error;
        if (typeof data.detail === "string") return data.detail;

        // DRF field errors: { username: ["..."], email: ["..."] }
        const messages = Object.entries(data)
          .flatMap(([field, val]) => {
            if (Array.isArray(val)) return val.map((m) => `${field}: ${m}`);
            if (typeof val === "string") return [`${field}: ${val}`];
            return [];
          })
          .join("\n");
        if (messages) return messages;
      }
    }

    // Flat error object (no response wrapper)
    if (error?.data?.detail) return error.data.detail;
    if (error?.data?.message) return error.data.message;
    if (error?.message) return error.message;
    if (error instanceof Error) return error.message;
    if (typeof error === "string") return error;
  } catch {
    // never crash the toast
  }

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

export function toastError(titleOrError: string | any, error?: any) {
  if (typeof titleOrError !== "string") {
    // called as toastError(e) — treat it like toastErrorFromError
    const message = parseApiError(titleOrError);
    showToast("error", { title: message });
    return;
  }
  const description = error ? parseApiError(error) : undefined;
  showToast("error", { title: titleOrError, description });
}

export function toastErrorFromError(error: any) {
  const message = parseApiError(error);
  showToast("error", { title: message });
}
