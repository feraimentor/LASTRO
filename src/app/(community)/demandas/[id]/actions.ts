"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireCommunityUser } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";

const responseSchema = z.object({
  report_id: z.string().uuid(), response_type: z.enum(["external_recorded", "official"]),
  attributed_to: z.string().trim().max(180).optional(), channel: z.string().trim().max(100).optional(),
  occurred_at: z.string().min(1), body: z.string().trim().min(5).max(10000),
  action_informed: z.string().trim().max(1000).optional(), official_representation_id: z.string().uuid().optional().or(z.literal("")),
  commitment_description: z.string().trim().max(1000).optional(), commitment_due_at: z.string().optional(),
  commitment_assigned_to: z.string().trim().max(180).optional(),
});

export async function recordResponseAction(formData: FormData) {
  await requireCommunityUser();
  const data = responseSchema.parse(Object.fromEntries(formData));
  const occurredAt = new Date(`${data.occurred_at}:00-03:00`).toISOString();
  const commitment = data.commitment_description ? {
    source_label: data.attributed_to || "Resposta oficial",
    assigned_to: data.commitment_assigned_to || null,
    description: data.commitment_description,
    assumed_at: occurredAt,
    due_at: data.commitment_due_at ? new Date(`${data.commitment_due_at}:00-03:00`).toISOString() : null,
  } : null;
  const supabase = await createClient();
  const { error } = await supabase.rpc("record_response", {
    p_report_id: data.report_id, p_response_type: data.response_type,
    p_attributed_to: data.attributed_to || null, p_channel: data.channel || null,
    p_occurred_at: occurredAt, p_body: data.body, p_action_informed: data.action_informed || null,
    p_official_representation_id: data.official_representation_id || null, p_case_grant_id: null,
    p_commitment: commitment,
  });
  if (error) throw new Error(error.message);
  revalidatePath(`/demandas/${data.report_id}`);
}

export async function setReportStatusAction(formData: FormData) {
  await requireCommunityUser();
  const data = z.object({ report_id: z.string().uuid(), status_slug: z.string().min(2), reason: z.string().trim().min(3).max(500) }).parse(Object.fromEntries(formData));
  const supabase = await createClient();
  const { error } = await supabase.rpc("set_report_status", { p_report_id: data.report_id, p_status_slug: data.status_slug, p_reason: data.reason });
  if (error) throw new Error(error.message);
  revalidatePath(`/demandas/${data.report_id}`);
}

export async function setOfficialStatusAction(formData: FormData) {
  await requireCommunityUser();
  const data = z.object({ report_id: z.string().uuid(), representation_id: z.string().uuid(), status: z.enum(["received","under_analysis","forwarded","in_execution","awaiting_third_party","service_reported_completed","closed_by_management"]), note: z.string().trim().max(1000).optional() }).parse(Object.fromEntries(formData));
  const supabase = await createClient();
  const { error } = await supabase.rpc("set_official_status", { p_report_id: data.report_id, p_representation_id: data.representation_id, p_status: data.status, p_note: data.note || null });
  if (error) throw new Error(error.message);
  revalidatePath(`/demandas/${data.report_id}`);
}

export async function flagReportAction(formData:FormData){await requireCommunityUser();const data=z.object({report_id:z.string().uuid(),reason:z.enum(["personal_data","harassment","potentially_inappropriate_allegation","spam","off_purpose","other"]),details:z.string().trim().max(1000).optional()}).parse(Object.fromEntries(formData));const supabase=await createClient();const{error}=await supabase.rpc("flag_report",{p_report_id:data.report_id,p_reason:data.reason,p_details:data.details||null});if(error)throw new Error(error.message);revalidatePath(`/demandas/${data.report_id}`)}
export async function submitModerationReviewAction(formData:FormData){await requireCommunityUser();const data=z.object({report_id:z.string().uuid(),action_id:z.string().uuid(),rationale:z.string().trim().min(10).max(2000)}).parse(Object.fromEntries(formData));const supabase=await createClient();const{error}=await supabase.rpc("submit_review_request",{p_moderation_action_id:data.action_id,p_suspension:false,p_rationale:data.rationale});if(error)throw new Error(error.message);revalidatePath(`/demandas/${data.report_id}`)}
