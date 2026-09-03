import { Circle } from "lucide-react";
import { cn } from "../../lib/utils";

type Tone = "healthy" | "warning" | "critical" | "unknown";

export function StatusIndicator({ label, tone = "unknown" }: { label: string; tone?: Tone }) {
  return (
    <span className="inline-flex items-center gap-2 text-[13px] text-muted-foreground">
      <Circle aria-hidden="true" className={cn("size-2 fill-current", `status-${tone}`)} />
      {label}
    </span>
  );
}
