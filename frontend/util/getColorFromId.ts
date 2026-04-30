export function getColorFromId(id: number) {
  if (!id) return "hsl(0, 0%, 85%)"; // fallback

  const hue = (id * 137.508) % 360;
  return `hsl(${hue}, 65%, 45%)`; // lighter for background
}
