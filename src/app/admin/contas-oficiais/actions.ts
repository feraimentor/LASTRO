"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requirePermission } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";

export async function verifyOfficialAction(formData: FormData) {
  await requirePermission("official_accounts.verify");
  const data = z.object({
    user_id:z.string().uuid(), role_type:z.enum(["manager","deputy_manager","council","administrator","authorized_representative","authorized_provider"]),
    organization:z.string().trim().max(180).optional(), starts_at:z.string().min(1), ends_at:z.string().optional(), reason:z.string().trim().min(5).max(500),
  }).parse(Object.fromEntries(formData));
  const supabase=await createClient();
  const {error}=await supabase.rpc("verify_official_representation",{
    p_user_id:data.user_id,p_role_type:data.role_type,p_organization:data.organization||null,
    p_starts_at:new Date(`${data.starts_at}:00-03:00`).toISOString(),
    p_ends_at:data.ends_at?new Date(`${data.ends_at}:00-03:00`).toISOString():null,p_reason:data.reason,
  });
  if(error)throw new Error(error.message==="recent_authentication_required"?"Confirme novamente sua conta Google.":error.message);
  revalidatePath("/admin/contas-oficiais");
}
