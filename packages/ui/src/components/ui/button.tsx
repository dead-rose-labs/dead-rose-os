import type { ButtonHTMLAttributes } from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "../../lib/utils";

const buttonVariants = cva(
  "inline-flex min-h-10 items-center justify-center gap-2 rounded-[var(--radius-control)] px-4 text-sm font-medium outline-none transition-[background-color,border-color,color,opacity] duration-150 ease-[var(--ease-out)] focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background disabled:pointer-events-none disabled:opacity-45",
  {
    variants: {
      variant: {
        primary: "bg-primary text-primary-foreground hover:bg-primary-hover",
        secondary: "border border-border bg-secondary text-secondary-foreground hover:bg-elevated",
        ghost: "text-muted-foreground hover:bg-elevated hover:text-foreground",
        destructive: "bg-destructive text-destructive-foreground hover:opacity-90",
      },
      size: { default: "h-10", sm: "h-9 min-h-9 px-3", icon: "size-10 p-0" },
    },
    defaultVariants: { variant: "primary", size: "default" },
  },
);

export type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & VariantProps<typeof buttonVariants>;

export function Button({ className, variant, size, type = "button", ...props }: ButtonProps) {
  return <button type={type} className={cn(buttonVariants({ variant, size }), className)} {...props} />;
}
