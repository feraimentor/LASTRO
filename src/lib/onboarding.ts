import { redirect } from "next/navigation";
import { createClient, getVerifiedUser } from "@/lib/supabase/server";

export type OnboardingStep = "legal" | "profile" | "unit" | "verification" | "pending" | "complete";

export async function getOnboardingStep(): Promise<OnboardingStep> {
  const user = await getVerifiedUser();
  if (!user) redirect("/login");
  const supabase = await createClient();
  const [{ data: versions }, { data: acceptances }, { data: profile }, { data: links }, { data: request }] = await Promise.all([
    supabase.from("legal_document_versions").select("id").eq("is_current", true).eq("state", "published"),
    supabase.from("user_legal_acceptances").select("document_version_id").eq("user_id", user.id),
    supabase.from("profiles").select("id,first_name,last_name,display_name,access_state").eq("id", user.id).maybeSingle(),
    supabase.from("resident_unit_links").select("id").eq("user_id", user.id).eq("verification_status", "approved").is("ended_at", null),
    supabase.from("verification_requests").select("id,state").eq("user_id", user.id).order("created_at", { ascending: false }).limit(1).maybeSingle(),
  ]);
  const accepted = new Set((acceptances ?? []).map((item) => item.document_version_id));
  if (!versions?.length || versions.some((version) => !accepted.has(version.id))) return "legal";
  if (!profile?.first_name || !profile.last_name || !profile.display_name) return "profile";
  if (links?.length && profile.access_state === "active") return "complete";
  if (!request) return "unit";
  if (request.state === "needs_information") return "verification";
  if (request.state === "rejected" || request.state === "cancelled") return "unit";
  return "pending";
}
export async function requireOnboardingStep(expected: OnboardingStep) {
  const current = await getOnboardingStep();
  if (current === "complete") redirect("/dashboard");
  if (current !== expected) redirect(`/onboarding/${current}`);
}
