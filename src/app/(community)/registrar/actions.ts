"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { requireCommunityUser } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";

const schema = z.object({
  type: z.enum(["complaint", "maintenance_request", "possible_irregularity", "information_request", "suggestion", "safety_risk"]),
  category: z.string().min(1), subcategory: z.string().optional(),
  title: z.string().trim().min(8).max(180), description: z.string().trim().min(20).max(10000),
  occurred_at: z.string().optional(), urgency: z.enum(["routine", "attention", "urgent", "possible_immediate_risk"]),
  scope: z.enum(["unit", "multiple_units", "block", "multiple_blocks", "common_area", "whole_condo", "unknown"]),
  identity_mode: z.enum(["identified", "protected", "protected_with_block"]),
  visibility: z.enum(["community", "restricted", "author_and_moderators"]),
  sensitivity: z.enum(["normal", "contains_personal_data", "identified_third_party", "child_or_adolescent", "possible_personal_risk", "sensitive_allegation"]), issue_id: z.string().uuid().optional().or(z.literal("")),
  suggested_category_text: z.string().trim().max(120).optional(), suggested_subcategory_text: z.string().trim().max(120).optional(),
  expected_responsible_party: z.string().trim().max(180).optional(), good_faith: z.literal("on"),
});

export async function createReportAction(formData: FormData) {
  await requireCommunityUser();
  const raw = Object.fromEntries(formData); const data = schema.parse(raw);
  const supabase = await createClient();
  const payload = { ...data, issue_id: data.issue_id || null, occurred_at: data.occurred_at || null,
    is_ongoing: formData.get("is_ongoing") === "on", previously_communicated: formData.get("previously_communicated") === "on",
    declared_recurrence: formData.get("declared_recurrence") === "on",
    identifies_third_party: formData.get("identifies_third_party") === "on",
    location_ids: formData.getAll("location_ids").map(String) };
  const { data: result, error } = await supabase.rpc("create_report", { p_payload: payload });
  if (error) throw new Error(`Não foi possível registrar: ${error.message}`);
  const protocol = Array.isArray(result) ? result[0]?.protocol : undefined;
  redirect(`/minhas-demandas?created=${encodeURIComponent(protocol ?? "ok")}`);
}
