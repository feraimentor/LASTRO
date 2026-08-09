import Link from "next/link";
import { PageHeader, EmptyState } from "@/components/community-shell";
import { KpiCard, ReportCard, type ReportSummary } from "@/components/record-cards";
import { createClient } from "@/lib/supabase/server";

export default async function DashboardPage() {
  const supabase = await createClient();
  const [{ data: recent }, { count: issues }, { count: reports }, { count: affected }] = await Promise.all([
    supabase.from("community_reports").select("id,protocol,issue_id,title,description,urgency,recorded_at,author_label,source_origin").order("recorded_at", { ascending: false }).limit(4),
    supabase.from("issues").select("id", { count: "exact", head: true }).is("archived_at", null),
    supabase.from("reports").select("id", { count: "exact", head: true }).is("archived_at", null),
    supabase.from("issue_affected_users").select("user_id", { count: "exact", head: true }),
  ]);
  return <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
    <PageHeader eyebrow="Comunidade verificada" title="O que precisa de atenção" description="Registros coletivos organizados com contexto, histórico e rastreabilidade." action={<Link href="/registrar" className="rounded-lg bg-brick px-5 py-3 font-bold text-white">Registrar relato</Link>}/>
    <section className="mt-7 grid gap-4 sm:grid-cols-3" aria-label="Resumo"><KpiCard label="Problemas coletivos" value={issues ?? 0} note="Issues não arquivadas"/><KpiCard label="Relatos registrados" value={reports ?? 0} note="Ocorrências, não pessoas"/><KpiCard label="Marcações de impacto" value={affected ?? 0} note="Pessoas que se declararam afetadas"/></section>
    <section className="mt-10"><div className="mb-4 flex items-center justify-between"><h2 className="text-2xl font-bold">Relatos recentes</h2><Link href="/problemas" className="font-semibold text-forest">Ver todos</Link></div>{recent?.length ? <div className="grid gap-4 lg:grid-cols-2">{(recent as ReportSummary[]).map((report) => <ReportCard key={report.id} report={report}/>)}</div> : <EmptyState title="A comunidade começa com um registro claro" body="Ainda não há relatos publicados. Antes de registrar, pesquise se o problema já existe." href="/registrar" label="Registrar o primeiro relato"/>}</section>
  </main>;
}
