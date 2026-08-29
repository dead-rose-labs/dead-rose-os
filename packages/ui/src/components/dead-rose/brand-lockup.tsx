export function BrandLockup({ compact = false }: { compact?: boolean }) {
  return (
    <div className="flex items-center gap-3" aria-label="Dead Rose OS">
      <img
        src="/dead-rose-os-logo.png"
        alt=""
        width={1254}
        height={1254}
        className={compact ? "size-9 object-contain" : "size-12 object-contain"}
      />
      <div className="flex flex-col">
        <span className="text-sm font-semibold tracking-[-0.01em] text-foreground">Dead Rose OS</span>
        {!compact && <span className="font-mono text-[11px] text-muted-foreground">SYSTEM CONTROL PLANE</span>}
      </div>
    </div>
  );
}
