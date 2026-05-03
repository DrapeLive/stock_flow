import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  allowedDevOrigins: ["192.168.1.5", "localhost"],
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
    ],
  },
};
export default nextConfig;
