import { OnboardingShell } from "@/components/onboarding-shell";
import { requireOnboardingStep } from "@/lib/onboarding";
import { saveProfile } from "../actions";

export const dynamic = "force-dynamic";
const input = "mt-1 min-h-12 w-full rounded-lg border border-[#aaa59e] bg-white px-3";
export default async function ProfileOnboardingPage() {
  await requireOnboardingStep("profile");
  return <OnboardingShell step={2} title="Como você participa da comunidade?" description="Estas informações ajudam a verificar seu vínculo. E-mail e WhatsApp nunca aparecem para moradores comuns.">
    <form action={saveProfile} className="grid gap-5 rounded-2xl bg-white p-6 shadow-sm sm:grid-cols-2">
      <label>Nome<input className={input} name="firstName" required minLength={2} autoComplete="given-name" /></label>
      <label>Sobrenome<input className={input} name="lastName" required minLength={2} autoComplete="family-name" /></label>
      <label className="sm:col-span-2">Nome de exibição<input className={input} name="displayName" required minLength={2} /></label>
      <label className="sm:col-span-2">Como aparecer nas publicações<select className={input} name="identity" defaultValue="identified"><option value="identified">Nome de exibição</option><option value="protected">Usuário condominial verificado</option><option value="protected_with_block">Identidade protegida com bloco</option></select></label>
      <p className="sm:col-span-2 rounded-lg bg-forest-soft p-3 text-sm">Identidade protegida vale perante a comunidade. Sua identidade real continua conhecida pela plataforma e por administradores autorizados.</p>
      <label className="sm:col-span-2">Relação com o condomínio<select className={input} name="relation" defaultValue="resident_owner"><option value="resident_owner">Proprietário residente</option><option value="nonresident_owner">Proprietário não residente</option><option value="tenant">Inquilino</option><option value="authorized_resident">Familiar/residente autorizado</option><option value="owner_representative">Representante do proprietário</option></select></label>
      <label className="sm:col-span-2">WhatsApp (opcional)<input className={input} name="whatsapp" maxLength={30} autoComplete="tel" inputMode="tel" /><span className="mt-1 block text-xs text-[#686a63]">Dado privado, nunca exibido à comunidade.</span></label>
      <fieldset className="sm:col-span-2"><legend>Reside atualmente no condomínio?</legend><div className="mt-2 flex gap-6"><label><input type="radio" name="currentlyResides" value="yes" required /> Sim</label><label><input type="radio" name="currentlyResides" value="no" required /> Não</label></div></fieldset>
      <button className="min-h-12 rounded-lg bg-forest px-5 py-3 font-bold text-white sm:col-span-2">Salvar e continuar</button>
    </form>
  </OnboardingShell>;
}
