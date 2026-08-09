import { ReauthenticateButton } from "@/components/reauthenticate-button";
import { requirePermission } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";
import { AdminHeader } from "../_components";
import { endLinkAction, setSuspensionAction } from "./actions";

export default async function Page() {
  await requirePermission("residents.verify");
  const supabase = await createClient();
  const { data: links } = await supabase.from("resident_unit_links").select("id,user_id,relation_type,verification_status,ended_at,condo_units(unit_label,blocks(label)),profiles!resident_unit_links_user_id_fkey(display_name,access_state)").order("created_at", { ascending: false }).limit(100);
  return <main>
    <AdminHeader title="Moradores e vínculos" description="Encerrar vínculo remove acesso comunitário sem apagar autoria, relatos ou histórico. Suspensão é independente do vínculo." />
    <div className="mt-5"><ReauthenticateButton nextPath="/admin/moradores" /></div>
    <div className="mt-6 space-y-4">{links?.map((link) => <article key={link.id} className="rounded-xl border bg-white p-5">
      <h2 className="font-bold">{link.profiles?.[0]?.display_name ?? link.user_id}</h2>
      <p className="mt-1 text-sm text-[#62645e]">{link.condo_units?.[0]?.blocks?.[0]?.label} · unidade {link.condo_units?.[0]?.unit_label} · {link.relation_type} · acesso {link.profiles?.[0]?.access_state}</p>
      {!link.ended_at && <form action={endLinkAction} className="mt-4 flex flex-wrap gap-2"><input type="hidden" name="link_id" value={link.id} /><input className="min-h-10 min-w-64 flex-1 rounded-lg border px-3" name="reason" required minLength={5} placeholder="Motivo do encerramento" /><button className="rounded-lg border border-danger px-3 font-bold text-danger">Encerrar vínculo</button></form>}
      <form action={setSuspensionAction} className="mt-3 flex flex-wrap gap-2"><input type="hidden" name="target_user_id" value={link.user_id} /><input className="min-h-10 min-w-64 flex-1 rounded-lg border px-3" name="reason" required minLength={5} placeholder="Motivo da suspensão/restauração" /><button name="suspend" value={link.profiles?.[0]?.access_state === "suspended" ? "false" : "true"} className="rounded-lg bg-[#262d29] px-3 font-bold text-white">{link.profiles?.[0]?.access_state === "suspended" ? "Restaurar acesso" : "Suspender acesso"}</button></form>
    </article>)}</div>
  </main>;
}
