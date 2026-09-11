"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requirePermission } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";

export async function endLinkAction(formData: FormData) {
  await requirePermission("residents.verify");
  const data = z.object({ link_id: z.string().uuid(), reason: z.string().trim().min(5).max(500) }).parse(Object.fromEntries(formData));
  const supabase = await createClient();
  const { error } = await supabase.rpc("end_resident_link", { p_link_id: data.link_id, p_reason: data.reason });
  if (error) throw new Error(error.message);
  revalidatePath("/admin/moradores");
  revalidatePath("/admin/usuarios");
}

export async function setSuspensionAction(formData: FormData) {
  await requirePermission("residents.suspend");
  const data = z.object({ target_user_id: z.string().uuid(), suspend: z.enum(["true", "false"]), reason: z.string().trim().min(5).max(500) }).parse(Object.fromEntries(formData));
  const supabase = await createClient();
  const { error } = await supabase.rpc("set_user_suspension", { p_target_user_id: data.target_user_id, p_suspend: data.suspend === "true", p_reason: data.reason });
  if (error) throw new Error(error.message === "recent_authentication_required" ? "Confirme novamente sua conta Google antes desta operação." : error.message);
  revalidatePath("/admin/moradores");
  revalidatePath("/admin/usuarios");
}
