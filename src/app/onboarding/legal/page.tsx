import { LegalAcceptanceCard } from "@/components/legal-acceptance-card";
import { OnboardingShell } from "@/components/onboarding-shell";
import { legalDocuments } from "@/lib/legal-documents";
import { requireOnboardingStep } from "@/lib/onboarding";
import { acceptCurrentLegalDocuments } from "../actions";

export const dynamic = "force-dynamic";
export default async function LegalOnboardingPage({ searchParams }: { searchParams: Promise<{ next?: string }> }) {
  await requireOnboardingStep("legal");
  const { next } = await searchParams;
  const nextPath = next?.startsWith("/") && !next.startsWith("//") ? next : "/onboarding/profile";
  return <OnboardingShell step={1} title="Antes de começar, leia e aceite as políticas" description="Cada aceite é separado. Você pode abrir os documentos completos e só terá acesso à comunidade depois das demais etapas e da verificação do vínculo.">
    <form action={acceptCurrentLegalDocuments} className="grid gap-4">
      <input type="hidden" name="next" value={nextPath} />
      {legalDocuments.map((document) => <LegalAcceptanceCard key={document.key} title={document.title} slug={document.slug} value={document.key} />)}
      <div className="mt-2 rounded-xl border border-[#d8d0c8] bg-white p-5"><button className="min-h-12 w-full rounded-lg bg-forest px-5 py-3 font-bold text-white">Confirmar os três aceites</button><p className="mt-3 text-center text-sm text-[#686a63]">Se você não concordar, feche esta página e encerre a sessão.</p></div>
    </form>
  </OnboardingShell>;
}
