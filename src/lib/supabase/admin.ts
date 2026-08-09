import "server-only";
import { createClient } from "@supabase/supabase-js";

export function createAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const secret = process.env.SUPABASE_SECRET_KEY;
  if (!url || !secret) return null;
  return createClient(url, secret, { auth: { autoRefreshToken: false, persistSession: false } });
}
export async function bootstrapFounderMaster(user: { id: string; email?: string | null }) {
  const expectedEmail = process.env.MASTER_BOOTSTRAP_EMAIL;
  if (!expectedEmail || user.email?.toLocaleLowerCase("pt-BR") !== expectedEmail.toLocaleLowerCase("pt-BR")) return;
  const admin = createAdminClient();
  if (!admin) return;
  const { data: masterRole } = await admin.from("roles").select("id").eq("slug", "master").single();
  if (!masterRole) return;
  const { data: existing } = await admin.from("user_roles").select("id").eq("user_id", user.id).eq("role_id", masterRole.id).is("revoked_at", null).maybeSingle();
  if (existing) return;
  const { error } = await admin.from("user_roles").insert({ user_id: user.id, role_id: masterRole.id, granted_by: user.id });
  if (error) throw error;
  await admin.from("audit_logs").insert({ actor_user_id: user.id, action: "master.bootstrap", target_type: "user", target_id: user.id, reason: "Bootstrap fundador validado por Google OAuth e ambiente" });
}
