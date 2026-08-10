import Link from "next/link";
import { Clock3, ShieldCheck } from "lucide-react";
import { OnboardingShell } from "@/components/onboarding-shell";
import { requireOnboardingStep } from "@/lib/onboarding";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export default async function PendingPage() {
  await requireOnboardingStep("pending");
  const supabase = await createClient();
  const { data: canReview } = await supabase.rpc("current_user_has_permission", { p_permission: "residents.verify" });
  return <OnboardingShell step={4} title="Solicitação enviada" description="Seu vínculo está aguardando verificação manual. Até a aprovação, o conteúdo da comunidade permanece protegido.">
    <div className="rounded-2xl border border-[#d8d0c8] bg-white p-7 text-center"><Clock3 className="mx-auto text-warning" size={34} aria-hidden="true" /><h2 className="mt-4 text-xl font-bold">Aguardando verificação</h2><p className="mt-2 text-[#5d5f58]">Você receberá uma notificação quando houver aprovação, pedido de complemento ou decisão.</p></div>
    {canReview && <div className="mt-5 rounded-2xl border border-forest/30 bg-white p-6"><ShieldCheck className="text-forest" aria-hidden="true"/><h2 className="mt-3 text-lg font-bold">Acesso administrativo disponível</h2><p className="mt-2 text-[#5d5f58]">Seu papel administrativo permite analisar esta fila mesmo antes da liberação do conteúdo comunitário.</p><Link href="/admin/verificacoes" className="mt-4 inline-flex min-h-11 items-center rounded-lg bg-forest px-4 py-2 font-bold text-white">Abrir verificações</Link></div>}
  </OnboardingShell>;
}
