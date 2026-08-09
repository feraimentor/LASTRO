import { Clock3 } from "lucide-react";
import { OnboardingShell } from "@/components/onboarding-shell";
import { requireOnboardingStep } from "@/lib/onboarding";

export const dynamic = "force-dynamic";
export default async function PendingPage() {
  await requireOnboardingStep("pending");
  return <OnboardingShell step={4} title="Solicitação enviada" description="Seu vínculo está aguardando verificação manual. Até a aprovação, o conteúdo da comunidade permanece protegido.">
    <div className="rounded-2xl border border-[#d8d0c8] bg-white p-7 text-center"><Clock3 className="mx-auto text-warning" size={34} aria-hidden="true" /><h2 className="mt-4 text-xl font-bold">Aguardando verificação</h2><p className="mt-2 text-[#5d5f58]">Você receberá uma notificação quando houver aprovação, pedido de complemento ou decisão.</p></div>
  </OnboardingShell>;
}
