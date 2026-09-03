export type ApplicationState = "live_installer" | "first_boot" | "login" | "dashboard";
export type BootMode = "live" | "installed";

export interface SystemInfo {
  hostname: string;
  os_name: string;
  version: string;
  kernel: string;
  architecture: string;
}

export interface InstallDisk {
  model: string;
  device: string;
  size_bytes: number;
  kind: string;
  removable: boolean;
  installation_media: boolean;
}

export type OperationPhase = "idle" | "preparing" | "installing_system" | "configuring_boot" | "finalizing" | "completed" | "failed";

export interface OperationStatus {
  phase: OperationPhase;
  detail: string;
  error: string | null;
}

export interface ApiError {
  code: string;
  message: string;
  component: string;
}

export interface CoreResponse<T> {
  id: string;
  ok: boolean;
  result: T | null;
  error: ApiError | null;
}
