export function formatBytes(value: number): string {
  if (!Number.isFinite(value) || value <= 0) return "Unknown capacity";
  const units = ["B", "KiB", "MiB", "GiB", "TiB"];
  const exponent = Math.min(Math.floor(Math.log(value) / Math.log(1024)), units.length - 1);
  const amount = value / 1024 ** exponent;
  return `${amount >= 100 ? amount.toFixed(0) : amount.toFixed(1)} ${units[exponent]}`;
}
