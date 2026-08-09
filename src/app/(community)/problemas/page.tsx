import { PageHeader, EmptyState } from "@/components/community-shell";
import { ReportCard, type ReportSummary } from "@/components/record-cards";
import { createClient } from "@/lib/supabase/server";

export default async function IssuesPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  const { q = "" } = await searchParams; const supabase = await createClient();
  const { data } = q.trim().length >= 2
    ? await supabase.rpc("search_community_reports", { p_query: q.trim(), p_limit: 50 })
    : await supabase.from("community_reports").select("id,protocol,issue_id,title,description,urgency,recorded_at,author_label,source_origin").order("recorded_at", { ascending: false }).limit(50);
  return <main className="mx-auto max-w-6xl px-4 py-8 sm:px-6"><PageHeader eyebrow="Busca comunitária" title="Problemas e relatos" description="Procure antes de criar um novo problema; você pode somar um relato a uma issue existente."/>
    <form className="my-6 flex gap-2"><label className="sr-only" htmlFor="q">Buscar</label><input id="q" name="q" defaultValue={q} placeholder="Ex.: vazamento no bloco 4" className="min-w-0 flex-1 rounded-xl border border-[#bcb5ad] bg-white px-4 py-3"/><button className="rounded-xl bg-forest px-5 font-bold text-white">Buscar</button></form>
    {data?.length ? <div className="grid gap-4 lg:grid-cols-2">{(data as ReportSummary[]).map((r) => <ReportCard key={r.id} report={r}/>)}</div> : <EmptyState title="Nenhum resultado" body="Tente termos mais amplos ou registre um novo relato com boa-fé e contexto suficiente." href="/registrar" label="Registrar relato"/>}
  </main>;
}
