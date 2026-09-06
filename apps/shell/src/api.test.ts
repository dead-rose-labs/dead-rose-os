import { describe, expect, it, vi } from "vitest";
import { invoke } from "@tauri-apps/api/core";
import { coreRequest } from "./api";
import type { Acknowledgement } from "./types";

vi.mock("@tauri-apps/api/core", () => ({ invoke: vi.fn() }));

describe("command acknowledgement", () => {
  it("accepts an explicit acknowledgement with exactly one request", async () => {
    vi.mocked(invoke).mockReset().mockResolvedValue({ ok: true, result: { accepted: true }, error: null });
    await expect(coreRequest<Acknowledgement>("start_install", { device: "/dev/test", confirmation: "ERASE" })).resolves.toEqual({ accepted: true });
    expect(invoke).toHaveBeenCalledTimes(1);
  });
  it("still rejects null success responses", async () => {
    vi.mocked(invoke).mockResolvedValue({ ok: true, result: null, error: null });
    await expect(coreRequest("start_install")).rejects.toThrow("Dead Rose Core returned an empty response");
  });
});
