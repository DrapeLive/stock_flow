import type { Area } from "react-easy-crop";

const toFile = (canvas: HTMLCanvasElement, suffix: string): Promise<File> =>
    new Promise((resolve, reject) =>
        canvas.toBlob(
            (blob) =>
                blob
                    ? resolve(
                          new File([blob], `img_${Date.now()}_${suffix}.webp`, {
                              type: "image/webp",
                          }),
                      )
                    : reject(new Error("Canvas is empty")),
            "image/webp",
            0.85,
        ),
    );

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
    return toFile(canvas, "crop");
}

export async function getFitFile(src: string): Promise<File> {
    const img = await loadImage(src);
    const max = 1200;
    const scale = Math.min(1, max / Math.max(img.width, img.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(img.width * scale);
    canvas.height = Math.round(img.height * scale);
    const ctx = canvas.getContext("2d")!;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
    return toFile(canvas, "fit");
}

function loadImage(src: string): Promise<HTMLImageElement> {
    return new Promise((res, rej) => {
        const img = new Image();
        img.onload = () => res(img);
        img.onerror = rej;
        img.src = src;
    });
}
