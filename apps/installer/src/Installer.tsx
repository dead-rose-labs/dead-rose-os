import { useCallback, useEffect, useMemo, useState, type FormEvent, type ReactNode } from "react";
import { Channel, invoke } from "@tauri-apps/api/core";
import { AlertTriangle, Check, HardDrive, RotateCw } from "lucide-react";
import {
  Alert,
  BrandLockup,
  Button,
  Field,
  FieldDescription,
  FieldGroup,
  FieldLabel,
  Input,
  Spinner,
  cn,
} from "@dead-rose/ui";

type Disk = { device: string; stableId: string; model: string; sizeBytes: number; removable: boolean };
type InstallRequest = {
  device: string;
  stableId: string;
  hostname: string;
  username: string;
  password: string;
  confirmation: string;
};
type InstallEvent = { phase: string; message: string };
type CommandError = { code?: string; message?: string };

const installerErrors: Record<string, string> = {
  disk_enumeration_failed: "Installation disks could not be enumerated. Check the installer service.",
  installer_media_unavailable: "The installer cannot verify its boot media. Recreate or reconnect the installation media.",
  confirmation_required: "Type ERASE to confirm the selected disk will be overwritten.",
  invalid_configuration: "Hostname or administrator details are invalid. Review the highlighted fields.",
  disk_too_small: "The selected disk is too small. Choose a disk with at least 32 GiB.",
  installer_media_selected: "The installer media cannot be erased. Choose a different disk.",
  target_not_found: "The selected disk is no longer available. Scan disks and choose the target again.",
  target_validation_failed: "The selected disk could not be validated. Choose another disk or inspect the installer log.",
  payload_verification_failed: "The operating-system payload failed verification. Recreate the installation media.",
  manifest_unavailable: "The release manifest is unavailable. Recreate the installation media.",
  invalid_manifest: "The release manifest is invalid. Recreate the installation media.",
  installation_engine_failed: "The Ubuntu installation engine could not install Dead Rose OS. Inspect the installer journal.",
  installation_in_progress: "Another installation is already in progress.",
  stable_disk_identity_missing: "The selected disk does not expose a stable hardware identity and cannot be erased safely.",
  stable_disk_identity_changed: "The selected disk identity changed. Scan disks again before installing.",
  root_partition_missing: "The installed ROOT partition could not be identified on the selected disk.",
  state_initialization_failed: "Persistent system state could not be initialized. Check the target disk.",
  administrator_creation_failed: "The administrator account could not be created. Check the installation log.",
  hostname_configuration_failed: "The system identity could not be saved. Check the installation log.",
  state_sync_failed: "Persistent state could not be synchronized. Do not boot from this installation.",
  restart_failed: "The system could not restart. Remove the installation media and restart manually.",
  progress_channel_failed: "Installer progress could not be reported safely. Review the installer log before retrying.",
  backend_unavailable: "The installer service is unavailable. Retry the connection; no disk has been changed.",
  backend_protocol_error: "The installer service returned an invalid response. Retry or collect graphical diagnostics.",
};

function installerError(error: unknown, fallback: string) {
  if (typeof error === "object" && error !== null) {
    const commandError = error as CommandError;
    if (commandError.code && installerErrors[commandError.code]) return installerErrors[commandError.code];
    if (commandError.message) return commandError.message;
  }
  return fallback;
}
const steps = [
  "Welcome",
  "Installation disk",
  "Hostname",
  "Administrator",
  "Confirm erase",
  "Install",
  "Complete",
  "Restart",
] as const;

function formatBytes(value: number) {
  return `${(value / 1024 ** 3).toFixed(1)} GiB`;
}

export function Installer() {
  const [step, setStep] = useState(0);
  const [disks, setDisks] = useState<Disk[]>([]);
  const [loadingDisks, setLoadingDisks] = useState(false);
  const [error, setError] = useState<string>();
  const [installPhase, setInstallPhase] = useState("Preparing installation…");
  const [request, setRequest] = useState<InstallRequest>({
    device: "",
    stableId: "",
    hostname: "dead-rose",
    username: "admin",
    password: "",
    confirmation: "",
  });
  const selectedDisk = useMemo(() => disks.find((disk) => disk.device === request.device), [disks, request.device]);

  const scanDisks = useCallback(() => {
    setLoadingDisks(true);
    setError(undefined);
    return invoke<Disk[]>("enumerate_disks")
      .then(setDisks)
      .catch((reason: unknown) =>
        setError(installerError(reason, "Installation disks could not be enumerated. Check the installer service.")),
      )
      .finally(() => setLoadingDisks(false));
  }, []);

  useEffect(() => {
    if (step === 1) void scanDisks();
  }, [scanDisks, step]);

  function update<K extends keyof InstallRequest>(key: K, value: InstallRequest[K]) {
    setRequest((current) => ({ ...current, [key]: value }));
  }
  function next() {
    setError(undefined);
    setStep((value) => Math.min(value + 1, steps.length - 1));
  }
  function back() {
    setError(undefined);
    setStep((value) => Math.max(value - 1, 0));
  }

  async function install() {
    if (request.confirmation !== "ERASE") {
      setError("Type ERASE to confirm the selected disk will be overwritten.");
      return;
    }
    setStep(5);
    setError(undefined);
    setInstallPhase("Preparing installation…");
    const progress = new Channel<InstallEvent>();
    progress.onmessage = (event) => setInstallPhase(event.message);
    try {
      await invoke("install", { request, progress });
      setStep(6);
    } catch (reason) {
      setError(installerError(reason, "Installation did not complete. Review the installer log and try again."));
      setStep(4);
    }
  }

  return (
    <main className="grid h-screen min-h-[720px] grid-cols-[260px_1fr] bg-background">
      <aside className="flex flex-col border-r border-border bg-card p-6">
        <BrandLockup />
        <nav className="mt-14 flex flex-col gap-1" aria-label="Installation progress">
          {steps.map((label, index) => (
            <div
              key={label}
              aria-current={index === step ? "step" : undefined}
              className={cn(
                "flex min-h-10 items-center gap-3 rounded-[var(--radius-control)] px-3 text-sm",
                index === step
                  ? "bg-accent text-foreground"
                  : index < step
                    ? "text-foreground"
                    : "text-muted-foreground",
              )}
            >
              <span
                className={cn(
                  "flex size-5 items-center justify-center rounded-full border font-mono text-[10px]",
                  index <= step ? "border-primary text-primary" : "border-border",
                )}
              >
                {index < step ? <Check aria-hidden="true" /> : index + 1}
              </span>
              {label}
            </div>
          ))}
        </nav>
        <p className="mt-auto font-mono text-[11px] text-muted-foreground">INSTALLER · 0.1.0</p>
      </aside>
      <section className="flex min-w-0 items-center justify-center p-12">
        <div className="w-full max-w-[680px]">
          {error && <Alert className="mb-6">{error}</Alert>}
          {step === 0 && (
            <Panel
              title="Install the control plane"
              description="This installer writes a verified Dead Rose OS image to a dedicated disk. The selected disk will be erased."
            >
              <Button onClick={next}>Begin installation</Button>
            </Panel>
          )}
          {step === 1 && (
            <Panel
              title="Select installation disk"
              description="Installer media is excluded automatically. Choose the target explicitly."
            >
              {loadingDisks ? (
                <div className="flex items-center gap-2 text-sm text-muted-foreground">
                  <Spinner />
                  Scanning disks…
                </div>
              ) : error ? (
                <Button variant="ghost" onClick={() => void scanDisks()} className="self-start">
                  <RotateCw data-icon="inline-start" aria-hidden="true" />
                  Retry disk scan
                </Button>
              ) : (
                <div className="flex flex-col gap-3">
                  {disks.length === 0 ? (
                    <p className="text-sm text-muted-foreground">No eligible installation disks found.</p>
                  ) : (
                    disks.map((disk) => (
                      <button
                        key={disk.device}
                        onClick={() =>
                          setRequest((current) => ({ ...current, device: disk.device, stableId: disk.stableId }))
                        }
                        className={cn(
                          "flex min-h-16 items-center gap-4 rounded-[var(--radius-control)] border p-4 text-left outline-none focus-visible:ring-2 focus-visible:ring-ring",
                          request.device === disk.device
                            ? "border-primary bg-accent"
                            : "border-border bg-card hover:bg-elevated",
                        )}
                      >
                        <HardDrive aria-hidden="true" />
                        <span className="flex flex-1 flex-col">
                          <span className="text-sm font-medium">{disk.model}</span>
                          <span className="font-mono text-xs text-muted-foreground">{disk.device}</span>
                        </span>
                        <span className="font-mono text-sm">{formatBytes(disk.sizeBytes)}</span>
                      </button>
                    ))
                  )}
                </div>
              )}
              <Actions onBack={back} onNext={next} nextDisabled={!request.device} />
            </Panel>
          )}
          {step === 2 && (
            <Panel
              title="Name this system"
              description="Use a hostname that identifies this control server on your network."
            >
              <Field>
                <FieldLabel htmlFor="hostname">Hostname</FieldLabel>
                <Input
                  id="hostname"
                  name="hostname"
                  className="font-mono"
                  value={request.hostname}
                  onChange={(event) => update("hostname", event.target.value)}
                  pattern="[a-z0-9-]+"
                  autoComplete="off"
                />
                <FieldDescription>Lowercase letters, numbers and hyphens.</FieldDescription>
              </Field>
              <Actions
                onBack={back}
                onNext={next}
                nextDisabled={!/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(request.hostname)}
              />
            </Panel>
          )}
          {step === 3 && <AdminStep request={request} update={update} onBack={back} onNext={next} />}
          {step === 4 && (
            <Panel
              title="Erase installation disk"
              description="This action is irreversible. Verify the exact target before continuing."
            >
              <div className="flex items-center gap-4 rounded-[var(--radius-control)] border border-destructive/40 bg-destructive/10 p-4">
                <AlertTriangle className="text-destructive" aria-hidden="true" />
                <div>
                  <p className="text-sm font-medium">{selectedDisk?.model ?? "Unknown disk"}</p>
                  <p className="font-mono text-xs text-muted-foreground">
                    {request.device} · {selectedDisk ? formatBytes(selectedDisk.sizeBytes) : "Unknown capacity"}
                  </p>
                </div>
              </div>
              <Field>
                <FieldLabel htmlFor="confirm">Type ERASE to continue</FieldLabel>
                <Input
                  id="confirm"
                  name="erase-confirmation"
                  value={request.confirmation}
                  onChange={(event) => update("confirmation", event.target.value)}
                  autoComplete="off"
                />
              </Field>
              <Actions
                onBack={back}
                onNext={install}
                nextLabel="Erase disk and install"
                destructive
                nextDisabled={request.confirmation !== "ERASE"}
              />
            </Panel>
          )}
          {step === 5 && (
            <Panel
              title="Writing Dead Rose OS"
              description="The installer reports each operation from the privileged backend. Do not power off this system."
            >
              <div className="flex items-center gap-3 rounded-[var(--radius-control)] border border-border bg-card p-4 text-sm">
                <Spinner />
                <span aria-live="polite">{installPhase}</span>
              </div>
            </Panel>
          )}
          {step === 6 && (
            <Panel
              title="Dead Rose OS is ready"
              description={`Remove the installation media, then restart into ${request.hostname}.`}
            >
              <Button
                onClick={() => {
                  setStep(7);
                  void invoke("restart").catch((reason: unknown) => {
                    setError(installerError(reason, installerErrors.restart_failed));
                    setStep(6);
                  });
                }}
              >
                <RotateCw data-icon="inline-start" aria-hidden="true" />
                Restart
              </Button>
            </Panel>
          )}
          {step === 7 && (
            <Panel title="Restarting" description="Dead Rose OS will start from the installed disk.">
              <div className="flex items-center gap-3 text-sm text-muted-foreground">
                <Spinner />
                Waiting for the system to restart…
              </div>
            </Panel>
          )}
        </div>
      </section>
    </main>
  );
}

function AdminStep({
  request,
  update,
  onBack,
  onNext,
}: {
  request: InstallRequest;
  update: <K extends keyof InstallRequest>(key: K, value: InstallRequest[K]) => void;
  onBack: () => void;
  onNext: () => void;
}) {
  function submit(event: FormEvent) {
    event.preventDefault();
    onNext();
  }
  return (
    <form onSubmit={submit}>
      <Panel title="Create administrator" description="This account authenticates locally to Dead Rose OS.">
        <FieldGroup>
          <Field>
            <FieldLabel htmlFor="username">Username</FieldLabel>
            <Input
              id="username"
              name="username"
              value={request.username}
              onChange={(event) => update("username", event.target.value)}
              autoComplete="username"
            />
          </Field>
          <Field>
            <FieldLabel htmlFor="password">Password</FieldLabel>
            <Input
              id="password"
              name="password"
              type="password"
              value={request.password}
              onChange={(event) => update("password", event.target.value)}
              autoComplete="new-password"
            />
            <FieldDescription>Use at least 12 characters.</FieldDescription>
          </Field>
        </FieldGroup>
        <Actions
          onBack={onBack}
          onNext={onNext}
          nextDisabled={!/^[a-z_][a-z0-9_-]{1,31}$/.test(request.username) || request.password.length < 12}
        />
      </Panel>
    </form>
  );
}

function Panel({ title, description, children }: { title: string; description: string; children: ReactNode }) {
  return (
    <div className="flex flex-col gap-8">
      <header className="flex max-w-xl flex-col gap-2">
        <h1 className="text-balance text-[30px] font-semibold leading-[38px] tracking-[-0.025em]">{title}</h1>
        <p className="text-sm leading-6 text-muted-foreground">{description}</p>
      </header>
      <div className="flex flex-col gap-6">{children}</div>
    </div>
  );
}
function Actions({
  onBack,
  onNext,
  nextDisabled,
  nextLabel = "Continue",
  destructive = false,
}: {
  onBack: () => void;
  onNext: () => void;
  nextDisabled?: boolean;
  nextLabel?: string;
  destructive?: boolean;
}) {
  return (
    <div className="mt-2 flex justify-between border-t border-border pt-6">
      <Button variant="ghost" onClick={onBack}>
        Back
      </Button>
      <Button variant={destructive ? "destructive" : "primary"} onClick={onNext} disabled={nextDisabled}>
        {nextLabel}
      </Button>
    </div>
  );
}
