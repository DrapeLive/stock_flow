import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    id: "/",
    name: "Stock Flow",
    short_name: "StockFlow",
    description: "Control your stock seamlessly.",
    start_url: "/login",
    display: "fullscreen",
    background_color: "#ffffff",
    theme_color: "#ff6200",
    icons: [
      {
        src: "/web-app-manifest-192x192.png",
        sizes: "192x192",
        type: "image/png",
        purpose: "any",
      },
      {
        src: "/web-app-manifest-512x512.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "any",
      },
      {
        src: "/web-app-manifest-512x512.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      },
    ],
    screenshots: [
      {
        src: "/mobile-screenshot.jpeg",
        sizes: "720x1485",
        type: "image/png",
      },
    ],
    protocol_handlers: [
      {
        protocol: "web+stockflow",
        url: "/open?url=%s",
      },
    ],
    display_override: ["window-controls-overlay", "standalone"],
  };
}
