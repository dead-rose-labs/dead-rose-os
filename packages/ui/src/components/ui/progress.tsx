import { cn } from "../../lib/utils";

export function Progress({ value, className }: { value?: number; className?: string }) {
  const determinate = typeof value === "number";
  return (
    <div
      role="progressbar"
      aria-valuemin={determinate ? 0 : undefined}
      aria-valuemax={determinate ? 100 : undefined}
      aria-valuenow={determinate ? value : undefined}
      aria-label={determinate ? `Progress: ${value}%` : "Operation in progress"}
      className={cn("h-1.5 w-full overflow-hidden rounded-full bg-muted", className)}
    >
      <div
        className={cn("h-full rounded-full bg-primary", determinate ? "transition-[width]" : "w-1/3 animate-operation")}
        style={determinate ? { width: `${Math.max(0, Math.min(value, 100))}%` } : undefined}
      />
    </div>
  );
}
