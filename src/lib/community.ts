import { redirect } from "next/navigation";
import { getOnboardingStep } from "@/lib/onboarding";
import { createClient, getVerifiedUser } from "@/lib/supabase/server";

export async function requireCommunityUser() {
  const user = await getVerifiedUser();
  if (!user) redirect("/login");
  const step = await getOnboardingStep();
  if (step !== "complete") redirect(`/onboarding/${step}`);
  return user;
}

export async function requireAdministrativeUser() {
  const user = await getVerifiedUser();
  if (!user) redirect("/login");

  const step = await getOnboardingStep();
  if (step === "legal" || step === "profile") redirect(`/onboarding/${step}`);

  return user;
}

export async function requirePermission(permission: string) {
  const user = await requireAdministrativeUser();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("current_user_has_permission", { p_permission: permission });
  if (error || !data) redirect("/dashboard");
  return user;
}
