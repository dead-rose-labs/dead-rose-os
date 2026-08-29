import type { ComponentProps, HTMLAttributes } from "react";
import { cn } from "../../lib/utils";

export function Input({ className, ...props }: ComponentProps<"input">) {
  return (
    <input
      className={cn(
        "h-10 w-full rounded-[var(--radius-control)] border border-input bg-background px-3 text-sm text-foreground outline-none placeholder:text-muted-foreground/70 focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/35 disabled:cursor-not-allowed disabled:opacity-45 aria-invalid:border-destructive aria-invalid:ring-destructive/25",
        className,
      )}
      {...props}
    />
  );
}

export function InputGroup(props: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      {...props}
      className={cn(
        "flex h-10 items-center rounded-[var(--radius-control)] border border-input bg-background focus-within:border-ring focus-within:ring-2 focus-within:ring-ring/35",
        props.className,
      )}
    />
  );
}

export function InputGroupInput({ className, ...props }: ComponentProps<"input">) {
  return (
    <input
      className={cn(
        "h-full min-w-0 flex-1 bg-transparent px-3 text-sm text-foreground outline-none placeholder:text-muted-foreground/70",
        className,
      )}
      {...props}
    />
  );
}

export function InputGroupAddon(props: HTMLAttributes<HTMLDivElement>) {
  return <div {...props} className={cn("flex h-full items-center px-1", props.className)} />;
}
