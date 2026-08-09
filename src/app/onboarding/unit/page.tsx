import { OnboardingShell } from "@/components/onboarding-shell";
import { requireOnboardingStep } from "@/lib/onboarding";
import { createClient } from "@/lib/supabase/server";
import { requestVerification } from "../actions";

export const dynamic = "force-dynamic";
const field = "mt-1 min-h-12 w-full rounded-lg border border-[#aaa59e] bg-white px-3";
export default async function UnitOnboardingPage() {
  await requireOnboardingStep("unit");
  const supabase = await createClient();
  const { data: units } = await supabase.from("condo_units").select("id,unit_label,block_id").is("archived_at", null).order("block_id").order("unit_label");
  return <OnboardingShell step={3} title="Informe seu bloco e sua unidade" description="Se a unidade ainda não estiver cadastrada, escreva o número ou identificação. Isso não impede o envio da solicitação.">
    <form action={requestVerification} className="grid gap-5 rounded-2xl bg-white p-6 shadow-sm">
      <label>Bloco<select className={field} name="blockId" required defaultValue=""><option value="" disabled>Selecione</option>{Array.from({ length: 14 }, (_, index) => <option key={index + 1} value={index + 1}>Bloco {index + 1}</option>)}</select></label>
      <label>Unidade cadastrada (se disponível)<select className={field} name="unitId" defaultValue=""><option value="">Não encontrei / informar abaixo</option>{units?.map((unit) => <option key={unit.id} value={unit.id}>Bloco {unit.block_id} — {unit.unit_label}</option>)}</select></label>
      <label>Unidade solicitada<input className={field} name="requestedUnit" maxLength={30} placeholder="Ex.: 302" /></label>
      <fieldset><legend>Reside atualmente?</legend><div className="mt-2 flex gap-6"><label><input type="radio" name="currentlyResides" value="yes" required /> Sim</label><label><input type="radio" name="currentlyResides" value="no" required /> Não</label></div></fieldset>
      <button className="min-h-12 rounded-lg bg-forest px-5 py-3 font-bold text-white">Enviar para verificação</button>
    </form>
  </OnboardingShell>;
}
