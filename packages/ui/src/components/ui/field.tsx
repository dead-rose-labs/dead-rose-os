import type { HTMLAttributes, LabelHTMLAttributes } from "react";
import { cn } from "../../lib/utils";

export function FieldGroup(props: HTMLAttributes<HTMLDivElement>) {
  return <div {...props} className={cn("flex flex-col gap-5", props.className)} />;
}

export function Field(props: HTMLAttributes<HTMLDivElement>) {
  return <div {...props} className={cn("flex flex-col gap-2", props.className)} />;
}

export function FieldLabel(props: LabelHTMLAttributes<HTMLLabelElement>) {
  return <label {...props} className={cn("text-[13px] font-medium text-foreground", props.className)} />;
}

export function FieldDescription(props: HTMLAttributes<HTMLParagraphElement>) {
  return <p {...props} className={cn("text-xs leading-4 text-muted-foreground", props.className)} />;
}
