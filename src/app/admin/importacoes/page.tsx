import Link from "next/link";
import { requirePermission } from "@/lib/community";
import { historicalImportColumns } from "@/lib/import-schema";
import { createClient } from "@/lib/supabase/server";
import { AdminEmpty, AdminHeader } from "../_components";
import {
  createManualImportAction,
  publishImportItemAction,
  reviewImportItemAction,
  uploadImportAction,
} from "./actions";

const field="rounded-lg border border-[#c8c0b7] bg-white px-3 py-2";
type Item={id:string;state:string;payload:Record<string,unknown>;validation_errors:unknown;created_at:string;published_report_id:string|null};

export default async function Page(){
  await requirePermission("historical_import.manage");
  const supabase=await createClient();
  const[{data:batches},{data:items},{data:issues}]=await Promise.all([
    supabase.from("import_batches").select("id,source_name,source_type,state,imported_at,completed_at").order("imported_at",{ascending:false}).limit(50),
    supabase.from("import_staging_items").select("id,state,payload,validation_errors,created_at,published_report_id").order("created_at",{ascending:false}).limit(100),
    supabase.from("issues").select("id,title").is("archived_at",null).order("created_at",{ascending:false}).limit(100),
  ]);
  return <main>
    <AdminHeader title="Importação histórica" description="CSV, XLSX e criação manual entram sempre em staging. Publicar ou associar exige curadoria explícita e preserva a proveniência."/>
    <section className="mt-6 grid gap-5 lg:grid-cols-2">
      <form action={uploadImportAction} className="rounded-2xl border bg-white p-5">
        <h2 className="text-xl font-bold">Importar arquivo estruturado</h2>
        <p className="mt-1 text-sm text-[#666861]">Até 1.000 registros e 5 MB. ZIP bruto do WhatsApp não é aceito.</p>
        <label className="mt-4 block text-sm font-semibold">Nome descritivo da fonte<input name="source_name" required minLength={2} maxLength={200} className={`${field} mt-1 w-full`} placeholder="Atas fictícias de 2025"/></label>
        <label className="mt-4 block text-sm font-semibold">Arquivo CSV ou XLSX<input name="file" type="file" required accept=".csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" className={`${field} mt-1 w-full`}/></label>
        <button className="mt-4 rounded-lg bg-forest px-4 py-2 font-bold text-white">Enviar ao staging</button>
        <div className="mt-4 flex flex-wrap gap-3 text-sm font-semibold"><Link href="/templates/historical_import_template.csv" className="underline">Baixar CSV</Link><Link href="/templates/historical_import_template.xlsx" className="underline">Baixar XLSX com instruções</Link></div>
      </form>
      <form action={createManualImportAction} className="rounded-2xl border bg-white p-5">
        <h2 className="text-xl font-bold">Criar registro manual</h2>
        <label className="mt-4 block text-sm font-semibold">Nome descritivo da fonte<input name="source_name" required className={`${field} mt-1 w-full`} placeholder="Registro manual fictício"/></label>
        <label className="mt-4 block text-sm font-semibold">Objeto JSON com as colunas do template<textarea name="payload" required rows={7} className={`${field} mt-1 w-full font-mono text-xs`} placeholder={JSON.stringify(Object.fromEntries(historicalImportColumns.map(column=>[column,""])),null,2)}/></label>
        <button className="mt-4 rounded-lg bg-forest px-4 py-2 font-bold text-white">Criar no staging</button>
      </form>
    </section>
    <section className="mt-8"><h2 className="text-2xl font-bold">Lotes</h2>{batches?.length?<div className="mt-4 overflow-x-auto rounded-xl border bg-white"><table className="w-full text-left text-sm"><thead className="bg-sand"><tr>{["Fonte","Formato","Estado","Importada"].map(header=><th key={header} className="px-4 py-3">{header}</th>)}</tr></thead><tbody>{batches.map(batch=><tr key={batch.id} className="border-t"><td className="px-4 py-3">{batch.source_name}</td><td className="px-4 py-3">{batch.source_type}</td><td className="px-4 py-3 font-semibold">{batch.state}</td><td className="px-4 py-3">{new Date(batch.imported_at).toLocaleString("pt-BR")}</td></tr>)}</tbody></table></div>:<AdminEmpty>Nenhum lote importado.</AdminEmpty>}</section>
    <section className="mt-8"><h2 className="text-2xl font-bold">Fila de curadoria</h2><div className="mt-4 grid gap-4">{(items as Item[]|null)?.map(item=><article key={item.id} className="rounded-2xl border bg-white p-5"><div className="flex flex-wrap items-start justify-between gap-3"><div><p className="text-xs font-bold uppercase tracking-wide text-forest">{item.state}</p><h3 className="text-lg font-bold">{String(item.payload.title??"Registro sem título válido")}</h3><p className="text-sm text-[#666861]">{String(item.payload.source_name??"Fonte pendente de correção")} · {new Date(item.created_at).toLocaleString("pt-BR")}</p></div>{item.published_report_id&&<Link href={`/demandas/${item.published_report_id}`} className="font-semibold underline">Abrir publicação</Link>}</div>{Array.isArray(item.validation_errors)&&item.validation_errors.length>0&&<div className="mt-3 rounded-lg border border-amber-300 bg-amber-50 p-3 text-sm"><b>Validação:</b> {item.validation_errors.map(String).join("; ")}</div>}{!["published","merged","ignored"].includes(item.state)&&<div className="mt-4 grid gap-4 xl:grid-cols-2"><form action={reviewImportItemAction} className="grid gap-2 rounded-xl bg-sand p-4"><input type="hidden" name="item_id" value={item.id}/><label className="text-sm font-semibold">Decisão<select name="state" className={`${field} mt-1 w-full`} defaultValue={item.state==="needs_edit"?"needs_edit":"approved"}><option value="approved">Aprovar</option><option value="needs_edit">Solicitar correção</option><option value="ignored">Ignorar</option></select></label><label className="text-sm font-semibold">Motivo<textarea name="reason" required minLength={5} rows={2} className={`${field} mt-1 w-full`}/></label><label className="text-sm font-semibold">Correção JSON parcial (opcional)<textarea name="edited_payload" rows={3} className={`${field} mt-1 w-full font-mono text-xs`} placeholder='{"published_summary":"Resumo corrigido..."}'/></label><button className="rounded-lg bg-forest px-4 py-2 font-bold text-white">Registrar decisão</button></form>{item.state==="approved"&&<form action={publishImportItemAction} className="grid content-start gap-2 rounded-xl border p-4"><input type="hidden" name="item_id" value={item.id}/><label className="text-sm font-semibold">Associar a issue existente (opcional)<select name="target_issue_id" className={`${field} mt-1 w-full`} defaultValue=""><option value="">Criar novo problema histórico</option>{issues?.map(issue=><option key={issue.id} value={issue.id}>{issue.title}</option>)}</select></label><p className="text-xs text-[#666861]">Sem seleção, cria uma issue histórica. Com seleção, preserva a associação como mesclagem curada.</p><button className="rounded-lg bg-[#8b3e2f] px-4 py-2 font-bold text-white">Publicar registro histórico</button></form>}</div>}</article>)}{!items?.length&&<AdminEmpty>Nenhum item aguardando curadoria.</AdminEmpty>}</div></section>
  </main>;
}
