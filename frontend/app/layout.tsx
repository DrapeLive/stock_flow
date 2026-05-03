import type { Metadata, Viewport } from "next";
import { Poppins } from "next/font/google";
import { Toaster } from "sonner";
import "./globals.css";
import { AuthProvider } from "@/context/AuthContext";
import ServiceWorkerRegister from "@/components/ServiceWorkerRegister";

const poppins = Poppins({
  variable: "--font-poppins",
  subsets: ["latin"],
  weight: ["300", "400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: "XL Apparals",
  description: "Control your stock seamlessly.",
  appleWebApp: {
    capable: true,
    title: "StockFlow",
    statusBarStyle: "black-translucent",
  },
  openGraph: {
    title: "StockFlow",
    description: "Control your stock seamlessly",
    url: "https://stockflow-sigma.vercel.app",
    siteName: "XL Apparals",
    images: [
      {
        url: "/opengraph.jpg",
        width: 1200,
        height: 630,
        alt: "StockFlow App",
      },
    ],
    type: "website",
  },
};

export const viewport: Viewport = {
  themeColor: "#FFFFFF",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${poppins.variable} antialiased  py-4 px-5 `}>
        <AuthProvider>
          <ServiceWorkerRegister />
          {children}
        </AuthProvider>
        <Toaster
          position="top-right"
          richColors
          toastOptions={{ duration: 3000 }}
        />
      </body>
    </html>
  );
}
