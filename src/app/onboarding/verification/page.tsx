import { OnboardingShell } from "@/components/onboarding-shell";
import { requireOnboardingStep } from "@/lib/onboarding";

export const dynamic = "force-dynamic";
export default async function VerificationPage() {
  await requireOnboardingStep("verification");
  return <OnboardingShell step={4} title="Precisamos de mais informações" description="A pessoa responsável pela verificação solicitou um complemento. A área de resposta será conectada à solicitação sem alterar o histórico já enviado.">
    <div className="rounded-2xl bg-white p-6"><p>Consulte a orientação recebida na sua solicitação e envie apenas os dados necessários. Não publique documentos pessoais em áreas comunitárias.</p></div>
  </OnboardingShell>;
}
