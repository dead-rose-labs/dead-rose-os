import { useEffect, useId, useRef, useState, type FormEvent } from "react";
import { Eye, EyeOff, LogOut } from "lucide-react";
import {
  Alert,
  BrandLockup,
  Button,
  Field,
  FieldDescription,
  FieldGroup,
  FieldLabel,
  Input,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  Spinner,
} from "@dead-rose/ui";
import { authenticate, logout, type AuthFailure } from "./auth";

type View = { name: "login" } | { name: "dashboard"; sessionId: string };

const authMessages: Record<AuthFailure, string> = {
  invalid_credentials: "The username or password is incorrect.",
  rate_limited: "Too many sign-in attempts. Wait a moment and try again.",
  internal_error: "Authentication is unavailable. Check the Dead Rose core service.",
};

export function App() {
  const [view, setView] = useState<View>({ name: "login" });
  return view.name === "login" ? (
    <LoginScreen onAuthenticated={(sessionId) => setView({ name: "dashboard", sessionId })} />
  ) : (
    <Dashboard sessionId={view.sessionId} onLogout={() => setView({ name: "login" })} />
  );
}

function LoginScreen({ onAuthenticated }: { onAuthenticated: (sessionId: string) => void }) {
  const usernameId = useId();
  const passwordId = useId();
  const passwordRef = useRef<HTMLInputElement>(null);
  const errorRef = useRef<HTMLDivElement>(null);
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string>();
  const [credentialError, setCredentialError] = useState(false);

  useEffect(() => {
    if (error) errorRef.current?.focus();
  }, [error]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (submitting) return;
    const form = new FormData(event.currentTarget);
    const username = String(form.get("username") ?? "").trim();
    const password = String(form.get("password") ?? "");
    if (!username || !password) {
      setError("Enter both username and password.");
      setCredentialError(true);
      return;
    }
    setSubmitting(true);
    setError(undefined);
    setCredentialError(false);
    try {
      const result = await authenticate(username, password);
      if (result.ok) onAuthenticated(result.sessionId);
      else {
        setError(authMessages[result.error]);
        const invalidCredentials = result.error === "invalid_credentials";
        setCredentialError(invalidCredentials);
        if (invalidCredentials) passwordRef.current?.select();
      }
    } catch {
      setError(authMessages.internal_error);
      setCredentialError(false);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="relative grid h-screen min-h-[720px] grid-cols-[minmax(400px,1fr)_minmax(520px,0.72fr)] overflow-hidden bg-background">
      <section
        className="relative flex min-w-0 flex-col justify-between border-r border-border p-10"
        aria-label="Dead Rose OS identity"
      >
        <BrandLockup />
        <div
          className="pointer-events-none absolute inset-0 flex items-center justify-center overflow-hidden"
          aria-hidden="true"
        >
          <img
            src="/dead-rose-os-logo.png"
            alt=""
            width={1254}
            height={1254}
            fetchPriority="high"
            className="h-[72vh] max-h-[760px] min-h-[500px] w-auto translate-x-[-2%] object-contain opacity-[0.22] saturate-[0.65]"
          />
        </div>
        <div className="relative max-w-md">
          <div className="mb-4 h-px w-16 bg-primary" />
          <p className="text-sm leading-6 text-muted-foreground">Local control interface</p>
          <p className="font-mono text-xs leading-5 text-muted-foreground/70">LOCAL AUTHENTICATION · OFFLINE READY</p>
        </div>
      </section>
      <section className="flex items-center justify-center bg-card px-16">
        <form onSubmit={submit} className="flex w-full max-w-[380px] flex-col gap-8" noValidate>
          <header className="flex flex-col gap-2">
            <h1 className="text-balance text-[32px] font-semibold leading-[38px] tracking-[-0.025em]">Sign in</h1>
            <p className="text-sm leading-5 text-muted-foreground">Use your Dead Rose administrator account.</p>
          </header>
          {error && (
            <Alert ref={errorRef} tabIndex={-1}>
              {error}
            </Alert>
          )}
          <FieldGroup>
            <Field data-invalid={credentialError || undefined}>
              <FieldLabel htmlFor={usernameId}>Username</FieldLabel>
              <Input
                id={usernameId}
                name="username"
                autoComplete="username"
                autoCapitalize="none"
                spellCheck={false}
                disabled={submitting}
                aria-invalid={credentialError}
                autoFocus
              />
            </Field>
            <Field data-invalid={credentialError || undefined}>
              <FieldLabel htmlFor={passwordId}>Password</FieldLabel>
              <InputGroup>
                <InputGroupInput
                  ref={passwordRef}
                  id={passwordId}
                  name="password"
                  type={showPassword ? "text" : "password"}
                  autoComplete="current-password"
                  disabled={submitting}
                  aria-invalid={credentialError}
                  aria-describedby={error ? `${passwordId}-error` : `${passwordId}-description`}
                />
                <InputGroupAddon>
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon"
                    className="min-h-8 size-8"
                    onClick={() => setShowPassword((value) => !value)}
                    aria-label={showPassword ? "Hide password" : "Show password"}
                  >
                    {showPassword ? <EyeOff aria-hidden="true" /> : <Eye aria-hidden="true" />}
                  </Button>
                </InputGroupAddon>
              </InputGroup>
              <FieldDescription id={error ? `${passwordId}-error` : `${passwordId}-description`}>
                {error ?? "Credentials remain on this device."}
              </FieldDescription>
            </Field>
          </FieldGroup>
          <Button type="submit" disabled={submitting} className="w-full">
            {submitting && <Spinner />} {submitting ? "Signing in…" : "Sign in"}
          </Button>
        </form>
      </section>
    </main>
  );
}

function Dashboard({ sessionId, onLogout }: { sessionId: string; onLogout: () => void }) {
  const [submitting, setSubmitting] = useState(false);
  async function signOut() {
    setSubmitting(true);
    try {
      await logout(sessionId);
    } finally {
      onLogout();
    }
  }
  return (
    <main className="view-enter grid h-screen grid-rows-[56px_1fr] bg-background">
      <header className="flex items-center justify-between border-b border-border px-5">
        <BrandLockup compact />
        <Button variant="ghost" size="sm" disabled={submitting} onClick={signOut}>
          <LogOut data-icon="inline-start" aria-hidden="true" />
          Sign out
        </Button>
      </header>
      <section className="flex items-center justify-center" aria-labelledby="dashboard-title">
        <div className="flex -translate-y-3 flex-col items-center gap-3 text-center">
          <span className="size-1.5 rounded-full bg-primary" aria-hidden="true" />
          <h1 id="dashboard-title" className="text-2xl font-semibold tracking-[-0.02em]">
            Coming soon
          </h1>
          <p className="font-mono text-xs text-muted-foreground">DEAD ROSE OS · 0.1.0</p>
        </div>
      </section>
    </main>
  );
}
