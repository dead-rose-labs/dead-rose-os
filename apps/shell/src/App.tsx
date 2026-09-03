import { useCallback, useEffect, useState } from "react";
import {
  AlertTriangle,
  Box,
  ChevronRight,
  Home,
  LoaderCircle,
  LockKeyhole,
  LogOut,
  RotateCcw,
  Server,
  Settings,
  Shield,
} from "lucide-react";
import {
  Badge,
  BrandLockup,
  Button,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  Progress,
  StatusIndicator,
  cn,
} from "@dead-rose/ui";
import { coreRequest, session } from "./api";
import { formatBytes } from "./format";
import type { ApplicationState, InstallDisk, OperationStatus, SystemInfo } from "./types";

const SESSION_TOKEN = () => session.get();

export function App() {
  const [mode, setMode] = useState<ApplicationState | null>(null);
  const [systemInfo, setSystemInfo] = useState<SystemInfo | null>(null);
  const [error, setError] = useState<string | null>(null);

  const bootstrap = useCallback(async () => {
    setError(null);
    try {
      const [nextMode, info] = await Promise.all([
        coreRequest<ApplicationState>("get_application_state", { session_token: SESSION_TOKEN() }),
        coreRequest<SystemInfo>("get_system_info"),
      ]);
      setMode(nextMode);
      setSystemInfo(info);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Dead Rose Core is unavailable");
    }
  }, []);

  useEffect(() => { void bootstrap(); }, [bootstrap]);

  if (error) return <Unavailable message={error} retry={bootstrap} />;
  if (!mode) return <Startup />;
  if (mode === "live_installer") return <Installer systemInfo={systemInfo} />;
  if (mode === "first_boot") return <FirstBoot onComplete={() => setMode("login")} />;
  if (mode === "login") return <Login onAuthenticated={() => setMode("dashboard")} />;
  return <Dashboard systemInfo={systemInfo} onLogout={async () => {
    const token = SESSION_TOKEN();
    if (token) await coreRequest("logout", { session_token: token });
    session.clear();
    setMode("login");
  }} />;
}

function Startup() {
  return (
    <main className="grid min-h-screen place-items-center bg-background">
      <div className="flex flex-col items-center gap-5" role="status" aria-live="polite">
        <BrandLockup />
        <LoaderCircle aria-hidden="true" className="size-5 animate-spin text-muted-foreground" />
        <span className="text-[13px] text-muted-foreground">Starting system interface…</span>
      </div>
    </main>
  );
}

function Unavailable({ message, retry }: { message: string; retry: () => Promise<void> }) {
  return (
    <main className="grid min-h-screen place-items-center bg-background p-8">
      <section className="w-full max-w-lg rounded-xl border border-border bg-card p-8" aria-labelledby="core-error-title">
        <AlertTriangle aria-hidden="true" className="mb-5 size-6 text-destructive" />
        <h1 id="core-error-title" className="text-xl font-semibold">System interface unavailable</h1>
        <p className="mt-2 leading-5 text-muted-foreground">Dead Rose Core could not be reached. System controls are unavailable until the service recovers.</p>
        <p className="mt-4 rounded-md bg-muted p-3 font-mono text-xs text-muted-foreground">{message}</p>
        <Button className="mt-6" onClick={() => void retry()}><RotateCcw data-icon="inline-start" />Retry connection</Button>
      </section>
    </main>
  );
}

function Installer({ systemInfo }: { systemInfo: SystemInfo | null }) {
  const [disks, setDisks] = useState<InstallDisk[]>([]);
  const [selected, setSelected] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [step, setStep] = useState<"welcome" | "disk" | "review" | "installing" | "complete">("welcome");
  const [status, setStatus] = useState<OperationStatus | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loadingDisks, setLoadingDisks] = useState(false);
  const [installPending, setInstallPending] = useState(false);

  const loadDisks = useCallback(async () => {
    setLoadingDisks(true); setError(null);
    try { setDisks(await coreRequest<InstallDisk[]>("list_install_disks")); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "Storage discovery failed"); }
    finally { setLoadingDisks(false); }
  }, []);

  useEffect(() => {
    if (step === "disk") void loadDisks();
  }, [step, loadDisks]);

  useEffect(() => {
    if (step !== "installing") return;
    const poll = window.setInterval(async () => {
      try {
        const next = await coreRequest<OperationStatus>("get_install_status");
        setStatus(next);
        if (next.phase === "completed") { window.clearInterval(poll); setStep("complete"); }
        if (next.phase === "failed") window.clearInterval(poll);
      } catch (reason) {
        setError(reason instanceof Error ? reason.message : "Installation status is unavailable");
        window.clearInterval(poll);
      }
    }, 1000);
    return () => window.clearInterval(poll);
  }, [step]);

  const target = disks.find((disk) => disk.device === selected);
  const startInstall = async () => {
    if (installPending) return;
    setInstallPending(true);
    setError(null);
    try {
      await coreRequest("start_install", { device: selected, confirmation });
      setStatus({ phase: "preparing", detail: "Preparing installation", error: null });
      setStep("installing");
    } catch (reason) { setError(reason instanceof Error ? reason.message : "Installation could not start"); }
    finally { setInstallPending(false); }
  };

  return (
    <main className="grid min-h-screen grid-cols-[minmax(280px,34%)_1fr] bg-background">
      <aside className="flex flex-col justify-between border-r border-border bg-card p-10">
        <BrandLockup />
        <div>
          <p className="max-w-sm text-3xl font-semibold leading-[1.15] tracking-[-0.03em]">A clean start for your control plane.</p>
          <p className="mt-4 max-w-sm leading-5 text-muted-foreground">Install Dead Rose OS on a dedicated disk. Installation, recovery, and future system updates are managed as one appliance lifecycle.</p>
        </div>
        <div className="flex items-center justify-between text-xs text-muted-foreground">
          <span className="font-mono">v{systemInfo?.version ?? "0.1.0"}</span>
          <StatusIndicator label="Installation media" tone="healthy" />
        </div>
      </aside>
      <section className="flex min-w-0 flex-col">
        <header className="flex h-14 items-center justify-between border-b border-border px-8">
          <span className="text-[13px] font-medium">{installerTitle(step)}</span>
          <span className="font-mono text-xs text-muted-foreground">{installerStep(step)}</span>
        </header>
        <div className="flex flex-1 items-center justify-center overflow-y-auto p-8">
          <div className="w-full max-w-2xl">
            {step === "welcome" && <Welcome onContinue={() => setStep("disk")} />}
            {step === "disk" && <DiskSelection disks={disks} selected={selected} setSelected={setSelected} loading={loadingDisks} error={error} retry={loadDisks} onContinue={() => setStep("review")} />}
            {step === "review" && target && <InstallReview disk={target} confirmation={confirmation} setConfirmation={setConfirmation} error={error} pending={installPending} back={() => setStep("disk")} start={startInstall} />}
            {step === "installing" && status && <Installing status={status} pollingError={error} retry={() => { setError(null); setConfirmation(""); setStep("disk"); }} />}
            {step === "complete" && <InstallComplete reboot={() => coreRequest("reboot", { session_token: null })} />}
          </div>
        </div>
      </section>
    </main>
  );
}

function Welcome({ onContinue }: { onContinue: () => void }) {
  return <div><h1 className="text-3xl font-semibold tracking-[-0.03em]">Install Dead Rose OS</h1><p className="mt-3 max-w-xl leading-5 text-muted-foreground">The selected disk will become a dedicated Dead Rose system. You will create the local administrator after the first boot.</p><Button className="mt-8" onClick={onContinue}>Choose installation disk<ChevronRight data-icon="inline-end" /></Button></div>;
}

function DiskSelection({ disks, selected, setSelected, loading, error, retry, onContinue }: { disks: InstallDisk[]; selected: string; setSelected: (value: string) => void; loading: boolean; error: string | null; retry: () => Promise<void>; onContinue: () => void }) {
  return (
    <div><h1 className="text-2xl font-semibold tracking-[-0.02em]">Select installation disk</h1><p className="mt-2 text-muted-foreground">Choose a physical SSD or NVMe device. The installation media cannot be selected.</p>
      {loading && <div className="mt-8"><Progress /><p className="mt-3 text-[13px] text-muted-foreground">Discovering storage devices…</p></div>}
      {error && <div role="alert" className="mt-6 rounded-lg border border-destructive/40 bg-destructive/10 p-4"><p className="font-medium">Storage discovery failed</p><p className="mt-1 text-[13px] text-muted-foreground">{error}</p><Button variant="outline" size="sm" className="mt-4" onClick={() => void retry()}>Try again</Button></div>}
      {!loading && !error && <fieldset className="mt-6 flex flex-col gap-2"><legend className="sr-only">Available installation disks</legend>{disks.length === 0 ? <p className="rounded-lg border border-border bg-card p-5 text-muted-foreground">No eligible physical disks were found.</p> : disks.map((disk) => <label key={disk.device} className={cn("flex min-h-20 items-center gap-4 rounded-lg border bg-card px-5 py-4 transition-colors", selected === disk.device ? "border-primary bg-primary/5" : "border-border", disk.installation_media && "opacity-55")}><input type="radio" name="disk" value={disk.device} checked={selected === disk.device} disabled={disk.installation_media} onChange={() => setSelected(disk.device)} className="size-4 accent-[var(--primary)]" /><span className="min-w-0 flex-1"><span className="block font-medium">{disk.model}</span><span className="mt-1 block font-mono text-xs text-muted-foreground">{disk.device} · {formatBytes(disk.size_bytes)} · {disk.kind}</span></span>{disk.installation_media ? <Badge>In use</Badge> : disk.removable ? <Badge>Removable</Badge> : null}</label>)}</fieldset>}
      <div className="mt-8 flex justify-end"><Button disabled={!selected} onClick={onContinue}>Review installation<ChevronRight data-icon="inline-end" /></Button></div>
    </div>
  );
}

function InstallReview({ disk, confirmation, setConfirmation, error, pending, back, start }: { disk: InstallDisk; confirmation: string; setConfirmation: (value: string) => void; error: string | null; pending: boolean; back: () => void; start: () => Promise<void> }) {
  return (
    <div><h1 className="text-2xl font-semibold tracking-[-0.02em]">Review installation</h1><div className="mt-6 rounded-lg border border-border bg-card"><dl className="grid grid-cols-[160px_1fr] gap-y-3 p-5"><dt className="text-muted-foreground">Disk</dt><dd>{disk.model}</dd><dt className="text-muted-foreground">Device</dt><dd className="font-mono">{disk.device}</dd><dt className="text-muted-foreground">Capacity</dt><dd className="font-mono">{formatBytes(disk.size_bytes)}</dd></dl></div>
      <div className="mt-5 rounded-lg border border-destructive/40 bg-destructive/10 p-5"><p className="font-semibold text-destructive">ALL DATA ON THIS DISK WILL BE ERASED</p><p className="mt-2 text-[13px] leading-5 text-muted-foreground">This cannot be undone. Type <span className="font-mono text-foreground">ERASE</span> to confirm the exact disk above.</p></div>
      <FieldGroup className="mt-5"><Field data-invalid={Boolean(error)}><FieldLabel htmlFor="erase-confirmation">Confirmation</FieldLabel><Input id="erase-confirmation" value={confirmation} onChange={(event) => setConfirmation(event.target.value)} autoComplete="off" spellCheck={false} aria-invalid={Boolean(error)} className="font-mono" />{error && <FieldError>{error}</FieldError>}</Field></FieldGroup>
      <div className="mt-8 flex justify-between"><Button variant="ghost" disabled={pending} onClick={back}>Back</Button><Button variant="destructive" disabled={confirmation !== "ERASE" || pending} onClick={() => void start()}>{pending && <LoaderCircle data-icon="inline-start" className="animate-spin" />}Erase disk and install</Button></div>
    </div>
  );
}

function Installing({ status, pollingError, retry }: { status: OperationStatus; pollingError: string | null; retry: () => void }) {
  const failed = status.phase === "failed" || Boolean(pollingError);
  const failure = pollingError ?? status.error;
  return <div aria-live="polite"><h1 className="text-2xl font-semibold tracking-[-0.02em]">{failed ? "Installation status unavailable" : "Installing Dead Rose OS"}</h1><p className="mt-2 text-muted-foreground">{failed ? "The installer stopped receiving authoritative progress from Dead Rose Core." : status.detail}</p><div className="mt-8">{!failed && <Progress />}</div>{failure && <p role="alert" className="mt-5 rounded-lg border border-destructive/40 bg-destructive/10 p-4 text-[13px] leading-5">{failure}</p>}{failed && <Button className="mt-6" variant="outline" onClick={retry}>Recheck disks</Button>}<p className="mt-6 text-xs text-muted-foreground">Do not power off the system while installation is running. Detailed logs are preserved for diagnostics.</p></div>;
}

function InstallComplete({ reboot }: { reboot: () => Promise<unknown> }) {
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const restart = async () => { if (pending) return; setPending(true); setError(null); try { await reboot(); } catch (reason) { setError(reason instanceof Error ? reason.message : "Restart could not be requested"); setPending(false); } };
  return <div><StatusIndicator label="Installation complete" tone="healthy" /><h1 className="mt-5 text-3xl font-semibold tracking-[-0.03em]">Ready for first boot</h1><p className="mt-3 max-w-lg leading-5 text-muted-foreground">Remove the installation media. After restart, Dead Rose OS will open First Setup from the installed disk.</p>{error && <p role="alert" className="mt-5 rounded-lg border border-destructive/40 bg-destructive/10 p-4 text-[13px] leading-5">{error}</p>}<Button className="mt-8" disabled={pending} onClick={() => void restart()}>{pending && <LoaderCircle data-icon="inline-start" className="animate-spin" />}Restart system</Button></div>;
}

function FirstBoot({ onComplete }: { onComplete: () => void }) {
  const [username, setUsername] = useState(""); const [password, setPassword] = useState(""); const [confirmation, setConfirmation] = useState(""); const [error, setError] = useState<string | null>(null); const [pending, setPending] = useState(false);
  const submit = async (event: React.FormEvent) => { event.preventDefault(); if (password !== confirmation) { setError("Passwords do not match"); return; } setPending(true); setError(null); try { await coreRequest("create_admin", { username, password }); onComplete(); } catch (reason) { setError(reason instanceof Error ? reason.message : "Administrator could not be created"); } finally { setPending(false); } };
  return <AuthFrame title="Create local administrator" description="This account protects access to Dead Rose system controls."><form onSubmit={(event) => void submit(event)}><FieldGroup><Field><FieldLabel htmlFor="setup-username">Username</FieldLabel><Input id="setup-username" value={username} onChange={(event) => setUsername(event.target.value)} autoComplete="username" required minLength={3} maxLength={32} /></Field><Field><FieldLabel htmlFor="setup-password">Password</FieldLabel><Input id="setup-password" type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="new-password" required minLength={12} maxLength={1024} /><FieldDescription>Use at least 12 characters.</FieldDescription></Field><Field data-invalid={Boolean(error)}><FieldLabel htmlFor="setup-confirmation">Confirm password</FieldLabel><Input id="setup-confirmation" type="password" value={confirmation} onChange={(event) => setConfirmation(event.target.value)} autoComplete="new-password" required aria-invalid={Boolean(error)} />{error && <FieldError>{error}</FieldError>}</Field></FieldGroup><Button className="mt-6 w-full" disabled={pending}>{pending && <LoaderCircle data-icon="inline-start" className="animate-spin" />}Create administrator</Button></form></AuthFrame>;
}

function Login({ onAuthenticated }: { onAuthenticated: () => void }) {
  const [username, setUsername] = useState(""); const [password, setPassword] = useState(""); const [error, setError] = useState<string | null>(null); const [pending, setPending] = useState(false);
  const submit = async (event: React.FormEvent) => { event.preventDefault(); setPending(true); setError(null); try { const token = await coreRequest<string>("login", { username, password }); session.set(token); onAuthenticated(); } catch (reason) { setError(reason instanceof Error ? reason.message : "Login failed"); } finally { setPending(false); } };
  return <AuthFrame title="Welcome back" description="Sign in to manage this Dead Rose system."><form onSubmit={(event) => void submit(event)}><FieldGroup><Field><FieldLabel htmlFor="login-username">Username</FieldLabel><Input id="login-username" value={username} onChange={(event) => setUsername(event.target.value)} autoComplete="username" required autoFocus /></Field><Field data-invalid={Boolean(error)}><FieldLabel htmlFor="login-password">Password</FieldLabel><Input id="login-password" type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="current-password" required aria-invalid={Boolean(error)} />{error && <FieldError>{error}</FieldError>}</Field></FieldGroup><Button className="mt-6 w-full" disabled={pending}>{pending && <LoaderCircle data-icon="inline-start" className="animate-spin" />}Sign in</Button></form></AuthFrame>;
}

function AuthFrame({ title, description, children }: { title: string; description: string; children: React.ReactNode }) {
  return <main className="grid min-h-screen grid-cols-[1fr_minmax(440px,42%)] bg-background"><section className="flex flex-col justify-between p-10"><BrandLockup /><div className="max-w-xl"><p className="text-4xl font-semibold leading-[1.1] tracking-[-0.035em]">Your infrastructure begins here.</p><p className="mt-5 max-w-lg leading-6 text-muted-foreground">A private control plane with a deliberate system boundary, persistent local identity, and appliance-grade lifecycle.</p></div><span className="font-mono text-xs text-muted-foreground">Dead Rose OS · local console</span></section><section className="grid place-items-center border-l border-border bg-card p-10"><div className="w-full max-w-sm"><LockKeyhole aria-hidden="true" className="mb-6 size-6 text-primary" /><h1 className="text-3xl font-semibold tracking-[-0.03em]">{title}</h1><p className="mt-2 mb-7 leading-5 text-muted-foreground">{description}</p>{children}</div></section></main>;
}

function Dashboard({ systemInfo, onLogout }: { systemInfo: SystemInfo | null; onLogout: () => Promise<void> }) {
  const items = [{ label: "Deployments", icon: Box }, { label: "Nodes", icon: Server }, { label: "Security", icon: Shield }, { label: "Settings", icon: Settings }];
  return <div className="grid min-h-screen grid-cols-[232px_1fr] bg-background"><aside className="flex flex-col border-r border-border bg-card"><div className="flex h-14 items-center border-b border-border px-5"><BrandLockup /></div><nav aria-label="Primary navigation" className="flex flex-1 flex-col justify-between p-3"><div><div aria-current="page" className="flex min-h-10 w-full items-center gap-3 rounded-md bg-primary/10 px-3 text-left text-[13px] font-medium text-foreground"><Home aria-hidden="true" className="size-4 text-primary" />Overview</div><p className="px-3 pt-6 pb-2 text-xs font-medium text-muted-foreground">System</p>{items.slice(2).map(({ label, icon: Icon }) => <button key={label} disabled className="flex min-h-10 w-full items-center gap-3 rounded-md px-3 text-left text-[13px] text-muted-foreground opacity-60"><Icon aria-hidden="true" className="size-4" />{label}</button>)}</div><Button variant="ghost" className="justify-start" onClick={() => void onLogout()}><LogOut data-icon="inline-start" />Sign out</Button></nav></aside><main className="flex min-w-0 flex-col"><header className="flex h-14 items-center justify-between border-b border-border px-6"><div><span className="font-mono text-xs text-muted-foreground">{systemInfo?.hostname ?? "dead-rose"}</span></div><StatusIndicator label="Core connected" tone="healthy" /></header><div className="flex-1 overflow-y-auto p-6"><div className="mx-auto w-full max-w-[1440px]"><div className="flex items-end justify-between"><div><h1 className="text-2xl font-semibold tracking-[-0.02em]">Overview</h1><p className="mt-1 text-[13px] text-muted-foreground">Local control plane and system lifecycle.</p></div><span className="font-mono text-xs text-muted-foreground">v{systemInfo?.version ?? "0.1.0"}</span></div><section className="mt-8 border-y border-border"><dl className="grid grid-cols-3 divide-x divide-border"><SystemFact label="System" value={systemInfo?.os_name ?? "Unavailable"} /><SystemFact label="Kernel" value={systemInfo?.kernel ?? "Unavailable"} mono /><SystemFact label="Architecture" value={systemInfo?.architecture ?? "Unavailable"} mono /></dl></section><section className="mt-8"><h2 className="text-base font-semibold">Control plane</h2><p className="mt-1 text-[13px] text-muted-foreground">Feature surfaces reserved for the next milestone.</p><div className="mt-4 grid grid-cols-2 border-t border-l border-border">{items.map(({ label, icon: Icon }) => <div key={label} className="flex min-h-24 items-center gap-4 border-r border-b border-border bg-card px-5"><Icon aria-hidden="true" className="size-5 text-muted-foreground" /><div><p className="font-medium">{label}</p><p className="mt-1 text-xs text-muted-foreground">Planned</p></div></div>)}</div></section></div></div></main></div>;
}

function SystemFact({ label, value, mono = false }: { label: string; value: string; mono?: boolean }) { return <div className="px-5 py-4"><dt className="text-xs text-muted-foreground">{label}</dt><dd className={cn("mt-1.5 truncate text-[13px]", mono && "font-mono")}>{value}</dd></div>; }
function installerTitle(step: string) { return step === "complete" ? "Installation complete" : "Dead Rose Installer"; }
function installerStep(step: string) { return ({ welcome: "1 / 4", disk: "2 / 4", review: "3 / 4", installing: "4 / 4", complete: "Complete" } as Record<string, string>)[step]; }
