"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireCommunityUser } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";

const schema = z.object({ issue_id: z.string().uuid(), enabled: z.enum(["true", "false"]), unit_id: z.string().uuid().optional().or(z.literal("")) });

export async function setAffectedAction(formData: FormData) {
  await requireCommunityUser();
  const data = schema.parse(Object.fromEntries(formData));
  const supabase = await createClient();
  const { error } = await supabase.rpc("set_issue_affected", { p_issue_id: data.issue_id, p_affected: data.enabled === "true", p_unit_id: data.unit_id || null });
  if (error) throw new Error(error.message);
  revalidatePath(`/problemas/${data.issue_id}`);
}

export async function setFollowingAction(formData: FormData) {
  await requireCommunityUser();
  const data = schema.omit({ unit_id: true }).parse(Object.fromEntries(formData));
  const supabase = await createClient();
  const { error } = await supabase.rpc("set_issue_following", { p_issue_id: data.issue_id, p_following: data.enabled === "true" });
  if (error) throw new Error(error.message);
  revalidatePath(`/problemas/${data.issue_id}`);
}
