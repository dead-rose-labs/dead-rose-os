import type { ComponentProps } from "react";
import { cn } from "../../lib/utils";

export function Alert(props: ComponentProps<"div">) {
  return (
    <div
      role="alert"
      {...props}
      className={cn(
        "rounded-[var(--radius-control)] border border-destructive/35 bg-destructive/10 p-3 text-sm leading-5 text-foreground",
        props.className,
      )}
    />
  );
}
