import { notFound } from "next/navigation";
import { PageHeader } from "@/components/community-shell";
import { ReportCard, type ReportSummary, StatusBadge } from "@/components/record-cards";
import { createClient } from "@/lib/supabase/server";
import { setAffectedAction, setFollowingAction } from "./actions";

export default async function IssueDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params; const supabase = await createClient();
  const [{ data: issue }, { data: reports }, { data: metrics }, { data: events }, { data: relationship }, { data: links }] = await Promise.all([
    supabase.from("issues").select("id,title,derived_status,criticality,first_occurred_at,last_occurred_at,source_origin").eq("id", id).maybeSingle(),
    supabase.from("community_reports").select("id,protocol,issue_id,title,description,urgency,recorded_at,author_label,source_origin").eq("issue_id", id).order("recorded_at"),
    supabase.from("issue_metrics").select("report_count,affected_people_count,affected_unit_count,affected_block_count").eq("issue_id", id).maybeSingle(),
    supabase.from("timeline_events").select("id,event_type,display_text,occurred_at,recorded_at").eq("issue_id", id).order("recorded_at", { ascending: false }),
    supabase.rpc("current_issue_relationships", { p_issue_id: id }).maybeSingle(),
    supabase.from("resident_unit_links").select("unit_id,condo_units(unit_label,blocks(label))").eq("verification_status","approved").is("ended_at",null),
  ]); if (!issue) notFound();
  const currentRelationship = relationship as { is_affected: boolean; is_following: boolean } | null;
  return <main className="mx-auto max-w-6xl px-4 py-8 sm:px-6"><PageHeader eyebrow="Problema coletivo" title={issue.title} description="A issue agrupa relatos relacionados sem apagar a autoria ou a cronologia de cada registro."/>
    <section className="mt-6 grid gap-3 sm:grid-cols-4"><div className="rounded-xl bg-white p-4"><b>{metrics?.report_count ?? 0}</b><p className="text-sm">relatos</p></div><div className="rounded-xl bg-white p-4"><b>{metrics?.affected_people_count ?? 0}</b><p className="text-sm">pessoas afetadas</p></div><div className="rounded-xl bg-white p-4"><b>{metrics?.affected_unit_count ?? 0}</b><p className="text-sm">unidades</p></div><div className="rounded-xl bg-white p-4"><StatusBadge value={issue.derived_status}/><p className="mt-2 text-sm">estado coletivo derivado</p></div></section>
    <section className="mt-5 flex flex-wrap gap-3 rounded-xl border bg-white p-4"><form action={setAffectedAction} className="flex flex-wrap gap-2"><input type="hidden" name="issue_id" value={id}/><input type="hidden" name="enabled" value={currentRelationship?.is_affected?"false":"true"}/>{!currentRelationship?.is_affected&&links&&links.length>1&&<select name="unit_id" className="rounded-lg border px-3">{links.map(link=><option key={link.unit_id} value={link.unit_id}>{link.condo_units?.[0]?.blocks?.[0]?.label} · {link.condo_units?.[0]?.unit_label}</option>)}</select>}<button className="rounded-lg bg-brick px-4 py-2 font-bold text-white">{currentRelationship?.is_affected?"Retirar declaração":"Também sou afetado"}</button></form><form action={setFollowingAction}><input type="hidden" name="issue_id" value={id}/><input type="hidden" name="enabled" value={currentRelationship?.is_following?"false":"true"}/><button className="rounded-lg border border-forest px-4 py-2 font-bold text-forest">{currentRelationship?.is_following?"Deixar de acompanhar":"Acompanhar atualizações"}</button></form><a href={`/registrar?issue=${id}`} className="rounded-lg border px-4 py-2 font-bold">Adicionar meu próprio relato</a></section>
    <div className="mt-9 grid gap-8 lg:grid-cols-[1.5fr_.8fr]"><section><h2 className="mb-4 text-2xl font-bold">Relatos vinculados</h2><div className="space-y-4">{(reports as ReportSummary[] | null)?.map((r) => <ReportCard key={r.id} report={r}/>)}</div></section><aside><h2 className="text-xl font-bold">Linha do tempo</h2><ol className="mt-4 border-l-2 border-[#c9d7cd] pl-5">{events?.map((event) => <li key={event.id} className="relative pb-6 before:absolute before:-left-[1.65rem] before:top-1 before:h-3 before:w-3 before:rounded-full before:bg-forest"><p className="font-semibold">{event.display_text ?? event.event_type}</p><time className="text-xs text-[#6a6c65]">{new Intl.DateTimeFormat("pt-BR", { dateStyle: "medium", timeStyle: "short" }).format(new Date(event.occurred_at ?? event.recorded_at))}</time></li>)}</ol></aside></div>
  </main>;
}
