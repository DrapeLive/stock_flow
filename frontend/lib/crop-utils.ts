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

  return new Promise<File>((resolve, reject) =>
    canvas.toBlob(
      (blob) =>
        blob
          ? resolve(new File([blob], "cropped.jpg", { type: "image/jpeg" }))
          : reject(new Error("Canvas is empty")),
      "image/jpeg",
    ),
  );
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((res, rej) => {
    const img = new Image();
    img.onload = () => res(img);
    img.onerror = rej;
    img.src = src;
  });
}
