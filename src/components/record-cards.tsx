import Link from "next/link";

const urgencyLabels: Record<string,string> = { routine: "Rotina", attention: "Atenção", urgent: "Urgente", possible_immediate_risk: "Possível risco imediato" };

export function StatusBadge({ value }: { value: string }) {
  const risk = value === "urgent" || value === "possible_immediate_risk";
  return <span className={`inline-flex rounded-full px-2.5 py-1 text-xs font-bold ${risk ? "bg-[#f8dddd] text-danger" : "bg-forest-soft text-forest"}`}>{urgencyLabels[value] ?? value}</span>;
}

export type ReportSummary = { id: string; protocol: string; issue_id: string; title: string; description: string; urgency: string; recorded_at: string; author_label?: string | null; source_origin?: string };

export function ReportCard({ report }: { report: ReportSummary }) {
  return <article className="rounded-2xl border border-[#ded8d1] bg-white p-5 shadow-[0_8px_30px_rgba(58,49,43,.05)]">
    <div className="flex flex-wrap items-center justify-between gap-2"><span className="font-mono text-xs font-bold text-[#6b6d66]">{report.protocol}</span><StatusBadge value={report.urgency}/></div>
    <h2 className="mt-4 text-xl font-bold"><Link className="hover:text-forest" href={`/problemas/${report.issue_id}`}>{report.title}</Link></h2>
    <p className="mt-2 line-clamp-3 text-sm text-[#60625d]">{report.description}</p>
    <div className="mt-4 flex flex-wrap gap-x-4 gap-y-1 text-xs text-[#73756e]"><span>{new Intl.DateTimeFormat("pt-BR", { dateStyle: "medium" }).format(new Date(report.recorded_at))}</span>{report.author_label && <span>{report.author_label}</span>}{report.source_origin === "historical" && <span>Acervo histórico</span>}<Link href={`/demandas/${report.id}`} className="font-bold text-forest underline">Abrir relato</Link></div>
  </article>;
}

export function KpiCard({ label, value, note }: { label: string; value: string | number; note: string }) {
  return <article className="rounded-2xl border border-[#ded8d1] bg-white p-5"><p className="text-sm font-semibold text-[#64665f]">{label}</p><p className="mt-2 text-3xl font-bold text-brick">{value}</p><p className="mt-2 text-xs text-[#74766f]">{note}</p></article>;
}
