/**
 * Flatten a nested object into FormData compatible with Django REST Framework's multipart parser.
 * Handles nested arrays and objects like `variants[0]image` or `sizes[0]size`.
 */
export function objectToFormData(
    obj: any,
    rootName?: string,
    ignoreList?: string[]
): FormData {
    const formData = new FormData();

    function appendFormData(data: any, root: string) {
        if (!data) return;

        if (ignoreList && ignoreList.indexOf(root) !== -1) return;

        if (data instanceof File) {
            formData.append(root, data);
        } else if (Array.isArray(data)) {
            for (let i = 0; i < data.length; i++) {
                appendFormData(data[i], `${root}[${i}]`);
            }
        } else if (typeof data === "object" && data !== null) {
            for (const key in data) {
                if (Object.prototype.hasOwnProperty.call(data, key)) {
                    if (root === "") {
                        appendFormData(data[key], key);
                    } else {
                        appendFormData(data[key], `${root}${key}`);
                    }
                }
            }
        } else {
            if (data !== undefined && data !== null) {
                formData.append(root, data.toString());
            }
        }
    }

    appendFormData(obj, rootName || "");

    return formData;
}

/**
 * Specifically tailored for ItemRequest structure in Django
 */
export function itemToFormData(data: any): FormData {
    const formData = new FormData();
    formData.append("name", data.name);
    formData.append("description", data.description || "");
    formData.append("price", data.price);
    formData.append("type", data.type);

    data.sizes.forEach((size: any, index: number) => {
        formData.append(`sizes[${index}]size`, size.size);
        formData.append(`sizes[${index}]stock`, size.stock.toString());
    });

    data.variants.forEach((variant: any, index: number) => {
        formData.append(`variants[${index}]color`, variant.color);
        if (variant.image) {
            formData.append(`variants[${index}]image`, variant.image);
        }
    });

    return formData;
}
