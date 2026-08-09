import { CommunityShell } from "@/components/community-shell";
import { requireCommunityUser } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";

export default async function CommunityLayout({ children }: { children: React.ReactNode }) {
  await requireCommunityUser();
  const supabase = await createClient();
  const { data } = await supabase.rpc("current_user_has_permission", { p_permission: "admins.manage" });
  return <CommunityShell admin={Boolean(data)}>{children}</CommunityShell>;
}
