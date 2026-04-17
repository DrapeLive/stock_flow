import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

function isTokenExpired(token: string) {
  try {
    const base64Url = token.split(".")[1];
    const base64 = base64Url.replace(/-/g, "+").replace(/_/g, "/");
    const jsonPayload = decodeURIComponent(
      atob(base64)
        .split("")
        .map(function (c) {
          return "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2);
        })
        .join(""),
    );

    const payload = JSON.parse(jsonPayload);
    // Add 5 seconds buffer
    if (payload.exp && payload.exp * 1000 <= Date.now() + 5000) {
      return true;
    }
    return false;
  } catch (error) {
    return true; // invalid token
  }
}

export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;

  const publicRoutes = ["/login", "/reset-password"];
  const isPublic = publicRoutes.some((route) => pathname.startsWith(route));

  const token = request.cookies.get("token")?.value;
  const role = request.cookies.get("role")?.value;

  // Check if token exists but is expired/invalid
  if (token && isTokenExpired(token)) {
    const response = NextResponse.redirect(new URL("/login", request.url));
    response.cookies.delete("token");
    response.cookies.delete("role");
    response.cookies.delete("auth_user");
    response.cookies.delete("auth_refresh");
    return response;
  }

  // Not logged in -> redirect to login
  if (!token && !isPublic) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  // Logged in but trying to access login page -> redirect home
  if (token && isPublic) {
    return NextResponse.redirect(new URL("/", request.url));
  }

  // 🔹 NEW: If admin tries to access root -> redirect to /admin
  if (token && role === "ADMIN" && pathname === "/") {
    return NextResponse.redirect(new URL("/admin", request.url));
  }

  // Non-admin trying to access admin
  if (pathname.startsWith("/admin") && role !== "ADMIN") {
    return NextResponse.redirect(new URL("/", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/((?!api|_next/static|_next/image|favicon.ico|sw.js|manifest.webmanifest|robots.txt|sitemap.xml).*)",
  ],
};
