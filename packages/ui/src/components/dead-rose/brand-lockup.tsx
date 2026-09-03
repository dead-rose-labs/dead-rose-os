export function BrandLockup({ compact = false }: { compact?: boolean }) {
  return (
    <div className="flex items-center gap-3" aria-label="Dead Rose OS">
      <span aria-hidden="true" className="brand-mark" />
      {!compact && <span className="text-sm font-semibold tracking-[-0.02em]">Dead Rose OS</span>}
    </div>
  );
}
