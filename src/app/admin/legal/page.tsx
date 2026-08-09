import Link from "next/link";
import { ReauthenticateButton } from "@/components/reauthenticate-button";
import { requirePermission } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";
import { AdminHeader, DataTable } from "../_components";
import { createLegalDraftAction, publishLegalVersionAction } from "./actions";

const input = "min-h-11 rounded-lg border border-[#aaa59e] bg-white px-3";

export default async function Page() {
  await requirePermission("legal_documents.manage");
  const supabase = await createClient();
  const [{ data: versions }, { data: recent }] = await Promise.all([
    supabase.from("legal_document_versions").select("id,version,state,published_at,effective_at,requires_reacceptance,is_current,download_path,content_hash_sha256,legal_documents(title,key,public_slug)").order("created_at", { ascending: false }),
    supabase.rpc("current_session_is_recent"),
  ]);
  const drafts = versions?.filter((version) => version.state === "draft") ?? [];
  return <main>
    <AdminHeader title="Documentos jurídicos" description="Rascunhos podem ser revistos; snapshots publicados não podem ser alterados. Mudança material exige reaceite." />
    <div className="mt-4 flex flex-wrap items-center gap-4"><Link href="/legal" className="font-semibold text-forest">Abrir políticas públicas →</Link><span className="text-sm">Sessão recente: <b>{recent ? "sim" : "não"}</b></span><ReauthenticateButton nextPath="/admin/legal" /></div>
    <form action={createLegalDraftAction} className="mt-6 grid gap-3 rounded-xl border bg-white p-5">
      <h2 className="text-lg font-bold">Novo rascunho</h2>
      <div className="grid gap-3 sm:grid-cols-2"><select className={input} name="document_key"><option value="notifications_communication">Notificações e comunicação</option><option value="responsible_use_moderation">Uso responsável e moderação</option><option value="privacy_terms">Privacidade e termos</option></select><input className={input} name="version" required placeholder="Versão, ex.: 1.1" /></div>
      <textarea className="min-h-64 rounded-lg border border-[#aaa59e] p-3 font-mono text-sm" name="content_markdown" required minLength={100} placeholder="Conteúdo Markdown integral" />
      <input className={input} name="download_path" placeholder="Caminho do DOCX (pode ser informado na publicação)" />
      <label className="flex gap-2"><input type="checkbox" name="requires_reacceptance" defaultChecked /> Alteração material: exigir novo aceite</label>
      <button className="min-h-11 rounded-lg bg-forest px-4 font-bold text-white">Criar rascunho com hash SHA-256</button>
    </form>
    {drafts.map((draft) => <form key={draft.id} action={publishLegalVersionAction} className="mt-4 grid gap-3 rounded-xl border border-gold bg-[#fffaf0] p-5 sm:grid-cols-2">
      <input type="hidden" name="version_id" value={draft.id} />
      <div className="sm:col-span-2"><b>{draft.legal_documents?.[0]?.title} · versão {draft.version}</b><p className="mt-1 break-all text-xs">SHA-256: {draft.content_hash_sha256}</p></div>
      <label>Vigência (America/São Paulo)<input className={`${input} mt-1 w-full`} type="datetime-local" name="effective_at" required /></label>
      <label>Download DOCX<input className={`${input} mt-1 w-full`} name="download_path" defaultValue={draft.download_path ?? ""} required /></label>
      <button className="min-h-11 rounded-lg bg-brick px-4 font-bold text-white sm:col-span-2">Publicar versão imutável</button>
    </form>)}
    <DataTable headers={["Documento", "Versão", "Estado", "Reaceite", "Vigente"]} rows={(versions ?? []).map((version) => [version.legal_documents?.[0]?.title, version.version, version.state, version.requires_reacceptance ? "Sim" : "Não", version.is_current ? "Sim" : "Não"])} />
  </main>;
}
