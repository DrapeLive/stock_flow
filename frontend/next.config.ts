import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  allowedDevOrigins: [
    "10.118.213.7",
    "localhost",
    "b3a3-2401-4900-6139-5722-957c-47bf-3282-53a6.ngrok-free.app",
  ],
  images: {
    remotePatterns: [
      ...(process.env.NEXT_PUBLIC_MEDIA_DOMAIN
        ? [
            {
              protocol: "https" as const,
              hostname: process.env.NEXT_PUBLIC_MEDIA_DOMAIN,
              pathname: "/media/**",
            },
          ]
        : []),
      {
        protocol: "https" as const,
        hostname: "*.ngrok-free.app",
        pathname: "/media/**",
      },
    ],
  },
  async headers() {
    return [
      {
        source: "/media/:path*",
        headers: [{ key: "ngrok-skip-browser-warning", value: "true" }],
      },
    ];
  },
};

export default nextConfig;
