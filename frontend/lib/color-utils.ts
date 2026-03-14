const PALETTE = [
  "Midnight Black",
  "Arctic White",
  "Navy Blue",
  "Forest Green",
  "Crimson Red",
  "Slate Grey",
  "Sandstone",
  "Ocean Teal",
  "Burnt Orange",
  "Dusty Rose",
  "Cobalt Blue",
  "Charcoal",
  "Olive",
  "Ivory",
  "Maroon",
  "Sky Blue",
  "Mocha Brown",
  "Sage Green",
  "Coral",
  "Lavender",
];

const used = new Set<string>();

export function pickColorName(): string {
  const available = PALETTE.filter((c) => !used.has(c));
  const pool = available.length > 0 ? available : PALETTE;
  const name = pool[Math.floor(Math.random() * pool.length)];
  used.add(name);
  return name;
}

export function releaseColorName(name: string) {
  used.delete(name);
}
