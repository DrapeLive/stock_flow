import type { Metadata } from "next";
import { Poppins } from "next/font/google";
import "../globals.css";
import Link from "next/link";
import { X } from "lucide-react";

const poppins = Poppins({
  variable: "--font-poppins",
  subsets: ["latin"],
  weight: ["300", "400", "500", "600", "700"],
});
export const metadata: Metadata = {
  title: "Stock Flow",
  description: "Manage all your orders in one place",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${poppins.variable} antialiased  py-4 px-5 `}>
        <h1 className="text-(--color-primary) flex justify-center">Create new Order</h1>
        {children}
        <div className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full">
            <div className="w-full flex justify-center pb-5">
                <Link  href="/" className="flex gap-1 text-(--color-primary) border border-(--color-primary) p-1.5 rounded-md">Cancel <span><X/></span></Link>
            </div>
        </div>
      </body>
    </html>
  );
}
