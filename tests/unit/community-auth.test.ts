import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  redirect: vi.fn((path: string) => { throw new Error(`redirect:${path}`); }),
  getOnboardingStep: vi.fn(),
  getVerifiedUser: vi.fn(),
  rpc: vi.fn(),
}));

vi.mock("next/navigation", () => ({ redirect: mocks.redirect }));
vi.mock("@/lib/onboarding", () => ({ getOnboardingStep: mocks.getOnboardingStep }));
vi.mock("@/lib/supabase/server", () => ({
  getVerifiedUser: mocks.getVerifiedUser,
  createClient: vi.fn(async () => ({ rpc: mocks.rpc })),
}));

import { requireAdministrativeUser, requirePermission } from "@/lib/community";

describe("administrative authorization", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.getVerifiedUser.mockResolvedValue({ id: "master-user" });
    mocks.getOnboardingStep.mockResolvedValue("pending");
    mocks.rpc.mockResolvedValue({ data: true, error: null });
  });

  it("allows a pending user only when current RBAC grants the requested permission", async () => {
    await expect(requirePermission("residents.verify")).resolves.toEqual({ id: "master-user" });
    expect(mocks.rpc).toHaveBeenCalledWith("current_user_has_permission", { p_permission: "residents.verify" });
  });

  it.each(["legal", "profile"] as const)("keeps the %s prerequisite before administrative access", async (step) => {
    mocks.getOnboardingStep.mockResolvedValue(step);
    await expect(requireAdministrativeUser()).rejects.toThrow(`redirect:/onboarding/${step}`);
  });

  it("rejects a pending user without the current database permission", async () => {
    mocks.rpc.mockResolvedValue({ data: false, error: null });
    await expect(requirePermission("residents.verify")).rejects.toThrow("redirect:/dashboard");
  });
});
