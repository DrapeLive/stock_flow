import type { Area } from "react-easy-crop";

export async function getCroppedFile(src: string, area: Area): Promise<File> {
    const img = await loadImage(src);
    const canvas = document.createElement("canvas");
    canvas.width = area.width;
    canvas.height = area.height;
    canvas
        .getContext("2d")!
        .drawImage(
            img,
            area.x,
            area.y,
            area.width,
            area.height,
            0,
            0,
            area.width,
            area.height,
        );
    return canvasToFile(canvas, "cropped.jpg");
}

// Passes the image through at original aspect ratio, capped at 1200px
export async function getFitFile(src: string): Promise<File> {
    const img = await loadImage(src);
    const max = 1200;
    const scale = Math.min(1, max / Math.max(img.width, img.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(img.width * scale);
    canvas.height = Math.round(img.height * scale);
    canvas.getContext("2d")!.drawImage(img, 0, 0, canvas.width, canvas.height);
    return canvasToFile(canvas, "fitted.jpg");
}

function loadImage(src: string): Promise<HTMLImageElement> {
    return new Promise((res, rej) => {
        const img = new Image();
        img.onload = () => res(img);
        img.onerror = rej;
        img.src = src;
    });
}

function canvasToFile(canvas: HTMLCanvasElement, name: string): Promise<File> {
    return new Promise((resolve, reject) =>
        canvas.toBlob(
            (blob) =>
                blob
                    ? resolve(new File([blob], name, { type: "image/jpeg" }))
                    : reject(new Error("Canvas is empty")),
            "image/jpeg",
        ),
    );
}
