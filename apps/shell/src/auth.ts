import { invoke } from "@tauri-apps/api/core";

export type AuthFailure = "invalid_credentials" | "rate_limited" | "internal_error";
export type AuthResult =
  | { ok: true; sessionId: string }
  | { ok: false; error: AuthFailure; retryAfterSeconds?: number };

export async function coreReadiness(): Promise<boolean> {
  return invoke<boolean>("core_readiness");
}

export async function authenticate(username: string, password: string): Promise<AuthResult> {
  return invoke<AuthResult>("authenticate", { username, password });
}

export async function logout(sessionId: string): Promise<void> {
  await invoke("logout", { sessionId });
}
