export function mediaUrl(path: string | null | undefined): string {
  if (!path) return "";

  if (path.startsWith("http")) {
    const url = new URL(path);
    path = url.pathname;
  }

  // Strip all possible prefixes
  const clean = path.replace(/^\/?api\/media\//, "").replace(/^\/?media\//, "");

  return `/api/media/${clean}`;
}
