import { PageHeader, EmptyState } from "@/components/community-shell";
import { ReportCard, type ReportSummary } from "@/components/record-cards";
import { requireCommunityUser } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";

export default async function MyReportsPage({ searchParams }: { searchParams: Promise<{ created?: string }> }) {
  const user = await requireCommunityUser(); const { created } = await searchParams; const supabase = await createClient();
  const { data } = await supabase.from("reports").select("id,protocol,issue_id,title,description,urgency,recorded_at,source_origin").eq("author_user_id", user.id).order("recorded_at", { ascending: false });
  return <main className="mx-auto max-w-5xl px-4 py-8 sm:px-6"><PageHeader eyebrow="Área pessoal" title="Meus relatos" description="O registro original, seus complementos e a evolução de cada demanda permanecem rastreáveis."/>{created && <p role="status" className="mt-5 rounded-xl bg-forest-soft p-4 font-semibold text-forest">Relato registrado com sucesso. Protocolo: {created}</p>}
    <section className="mt-7">{data?.length ? <div className="space-y-4">{(data as ReportSummary[]).map(r=><ReportCard key={r.id} report={r}/>)}</div>:<EmptyState title="Você ainda não registrou relatos" body="Pesquise a comunidade antes de iniciar um novo registro." href="/registrar" label="Registrar relato"/>}</section></main>;
}
