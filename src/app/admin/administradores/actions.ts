"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requirePermission } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";

const roleSchema = z.object({
  target_user_id: z.string().uuid(),
  role_slug: z.enum(["resident", "official", "moderator", "administrator", "master"]),
  action: z.enum(["grant", "revoke"]),
  reason: z.string().trim().min(5).max(500),
});

export async function setUserRoleAction(formData: FormData) {
  await requirePermission("admins.manage");
  const data = roleSchema.parse(Object.fromEntries(formData));
  const supabase = await createClient();
  const { error } = await supabase.rpc("set_user_role", {
    p_target_user_id: data.target_user_id,
    p_role_slug: data.role_slug,
    p_action: data.action,
    p_reason: data.reason,
  });
  if (error) throw new Error(error.message === "recent_authentication_required" ? "Confirme novamente sua conta Google antes desta operação." : error.message);
  revalidatePath("/admin/administradores");
  revalidatePath("/admin/usuarios");
}

const permissionSchema = z.object({
  target_user_id: z.string().uuid(),
  permission_slug: z.string().trim().min(3).max(100),
  effect: z.enum(["grant", "deny", "revoke"]),
  reason: z.string().trim().min(5).max(500),
});

export async function setPermissionOverrideAction(formData: FormData) {
  await requirePermission("admins.manage");
  const data = permissionSchema.parse(Object.fromEntries(formData));
  const supabase = await createClient();
  const { error } = await supabase.rpc("set_permission_override", {
    p_target_user_id: data.target_user_id,
    p_permission_slug: data.permission_slug,
    p_effect: data.effect,
    p_reason: data.reason,
  });
  if (error) throw new Error(error.message === "recent_authentication_required" ? "Confirme novamente sua conta Google antes desta operação." : error.message);
  revalidatePath("/admin/administradores");
  revalidatePath("/admin/usuarios");
}
