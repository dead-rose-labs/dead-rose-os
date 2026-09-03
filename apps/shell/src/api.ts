import { invoke } from "@tauri-apps/api/core";
import type { CoreResponse } from "./types";

export class CoreApiError extends Error {
  constructor(public readonly code: string, message: string, public readonly component: string) {
    super(message);
    this.name = "CoreApiError";
  }
}

export async function coreRequest<T>(method: string, params?: Record<string, unknown>): Promise<T> {
  const request = params === undefined ? { method } : { method, params };
  const response = await invoke<CoreResponse<T>>("core_request", { request });
  if (!response.ok || response.result === null) {
    throw new CoreApiError(
      response.error?.code ?? "core_unavailable",
      response.error?.message ?? "Dead Rose Core returned an empty response",
      response.error?.component ?? "dead-rose-core",
    );
  }
  return response.result;
}

export const session = {
  get: () => sessionStorage.getItem("dead-rose-session"),
  set: (token: string) => sessionStorage.setItem("dead-rose-session", token),
  clear: () => sessionStorage.removeItem("dead-rose-session"),
};
