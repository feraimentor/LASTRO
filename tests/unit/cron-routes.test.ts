import { afterEach, describe, expect, it, vi } from "vitest";

import { GET as commitmentsGet } from "@/app/api/cron/commitments/route";
import { GET as notificationsGet } from "@/app/api/cron/notifications/route";

describe("cron route contract", () => {
  afterEach(() => {
    delete process.env.CRON_SECRET;
    vi.restoreAllMocks();
  });

  it.each([
    ["commitments", commitmentsGet],
    ["notifications", notificationsGet],
  ])("exposes secured GET for %s", async (name, handler) => {
    vi.spyOn(console, "warn").mockImplementation(() => undefined);
    process.env.CRON_SECRET = "test-cron-secret";

    const response = await handler(
      new Request(`https://lastro.example/api/cron/${name}`) as never,
    );

    expect(response.status).toBe(401);
    await expect(response.json()).resolves.toEqual({ error: "unauthorized" });
  });
});
