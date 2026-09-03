import { Component, StrictMode, type ErrorInfo, type ReactNode } from "react";
import { createRoot } from "react-dom/client";
import { invoke } from "@tauri-apps/api/core";
import { AlertTriangle, RotateCw } from "lucide-react";
import "@dead-rose/ui/styles.css";
import { BrandLockup, Button } from "@dead-rose/ui";
import { Installer } from "./Installer";

class InstallerErrorBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    const message = `${error.name}: ${error.message}\n${info.componentStack ?? ""}`.slice(0, 8192);
    console.error("Dead Rose installer frontend failed", error, info);
    void invoke("report_frontend_error", { message }).catch(() => undefined);
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return (
      <main className="flex h-screen min-h-[480px] items-center justify-center bg-background p-8">
        <section className="flex w-full max-w-xl flex-col gap-8" role="alert">
          <BrandLockup />
          <div className="flex flex-col gap-3">
            <AlertTriangle className="size-7 text-destructive" aria-hidden="true" />
            <h1 className="text-[30px] font-semibold leading-[38px] tracking-[-0.025em]">
              Installer recovery
            </h1>
            <p className="max-w-[65ch] text-sm leading-6 text-muted-foreground">
              The installer interface stopped unexpectedly. Your disks have not been changed. Retry the interface; if
              the problem returns, collect the Dead Rose graphical diagnostics.
            </p>
          </div>
          <Button onClick={() => window.location.reload()} className="self-start">
            <RotateCw data-icon="inline-start" aria-hidden="true" />
            Retry installer
          </Button>
        </section>
      </main>
    );
  }
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <InstallerErrorBoundary>
      <Installer />
    </InstallerErrorBoundary>
  </StrictMode>,
);
