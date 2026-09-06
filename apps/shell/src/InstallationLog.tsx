import { useRef, useState } from "react";
import { Button } from "@dead-rose/ui";
import { coreRequest } from "./api";
import type { InstallerLog } from "./types";

export function InstallationLog() {
  const [log, setLog] = useState<InstallerLog | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [copyStatus, setCopyStatus] = useState("");
  const pending = useRef(false);
  const load = async () => {
    if (pending.current) return;
    pending.current = true;
    setLoading(true);
    setError(null);
    try { setLog(await coreRequest<InstallerLog>("get_install_log")); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Installation log is unavailable"); }
    finally { pending.current = false; setLoading(false); }
  };
  const copy = async () => {
    try { await navigator.clipboard.writeText(log?.text ?? ""); setCopyStatus("Log copied"); }
    catch { setCopyStatus("Clipboard unavailable. Select the log text to copy it."); }
  };
  return <details className="mt-5 min-w-0 rounded-lg border border-border bg-card p-4" onToggle={(event) => {
    if (event.currentTarget.open && !log) void load();
  }}>
    <summary className="cursor-pointer font-medium focus-visible:outline focus-visible:outline-ring">Show installation log</summary>
    {loading && <p role="status" className="mt-3 text-muted-foreground">Loading installation log…</p>}
    {error && <div className="mt-3"><p role="alert">{error}</p><Button className="mt-3" variant="outline" disabled={loading} onClick={() => void load()}>Retry log</Button></div>}
    {log && <>
      <p className="mt-3 text-xs text-muted-foreground">Last up to 200 lines (8 KiB maximum).{log.truncated && " Earlier or oversized lines omitted."}{log.redacted && " Sensitive content removed."}</p>
      <pre tabIndex={0} aria-label="Installation log" className="mt-3 max-h-72 min-w-0 overflow-y-auto whitespace-pre-wrap rounded-md bg-background p-3 font-mono text-xs leading-5 [overflow-wrap:anywhere]">{log.text || "The installation log is empty."}</pre>
      <div className="mt-3 flex flex-wrap items-center gap-3">
        {typeof navigator.clipboard?.writeText === "function" && <Button variant="outline" size="sm" disabled={!log.text} onClick={() => void copy()}>Copy log</Button>}
        <p role="status" className="text-xs text-muted-foreground">{copyStatus}</p>
      </div>
    </>}
  </details>;
}
