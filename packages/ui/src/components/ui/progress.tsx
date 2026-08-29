export function Progress({ value, label }: { value: number; label: string }) {
  return (
    <div className="flex flex-col gap-2">
      <div className="flex justify-between text-xs text-muted-foreground">
        <span>{label}</span>
        <span className="font-mono">{value}%</span>
      </div>
      <div
        className="h-1.5 overflow-hidden rounded-full bg-elevated"
        role="progressbar"
        aria-label={label}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={value}
      >
        <div
          className="h-full rounded-full bg-primary transition-transform duration-200 ease-[var(--ease-out)] motion-reduce:transition-none"
          style={{ transform: `translateX(${value - 100}%)` }}
        />
      </div>
    </div>
  );
}
