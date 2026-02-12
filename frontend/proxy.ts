import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function proxy(request: NextRequest) {
  console.log("Middleware running:", request.nextUrl.pathname);
  const { pathname } = request.nextUrl;

  const publicRoutes = ["/login", "/reset-password"];

  const isPublic = publicRoutes.some((route) => pathname.startsWith(route));

  const token = request.cookies.get("token")?.value;

  // Not logged in -> redirect to login
  if (!token && !isPublic) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  // Logged in but trying to access login page -> redirect home
  if (token && isPublic) {
    return NextResponse.redirect(new URL("/", request.url));
  }

  const role = request.cookies.get("role")?.value;

  if (pathname.startsWith("/admin") && role !== "ADMIN") {
    return NextResponse.redirect(new URL("/", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!api|_next|favicon.ico).*)"],
};
