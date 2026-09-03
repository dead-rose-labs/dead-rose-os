import { describe, expect, it } from "vitest";
import { formatBytes } from "./format";

describe("formatBytes", () => {
  it("uses binary infrastructure units", () => {
    expect(formatBytes(512 * 1024 ** 3)).toBe("512 GiB");
  });

  it("does not invent a capacity for missing data", () => {
    expect(formatBytes(0)).toBe("Unknown capacity");
  });
});
