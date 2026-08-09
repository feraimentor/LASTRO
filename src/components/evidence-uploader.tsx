"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { validateUploadMetadata } from "@/lib/upload-policy";

export function EvidenceUploader({ reportId }: { reportId: string }) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState<string>();

  async function upload(formData: FormData) {
    const file = formData.get("file");
    if (!(file instanceof File)) return;
    const validation = validateUploadMetadata(file);
    if (!validation.ok) { setMessage("Arquivo, extensão, MIME ou tamanho não permitido."); return; }
    setPending(true); setMessage(undefined);
    try {
      const digest = await crypto.subtle.digest("SHA-256", await file.arrayBuffer());
      const sha256 = Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
      const supabase = createClient();
      const { data: reservation, error: reserveError } = await supabase.rpc("reserve_report_attachment", {
        p_report_id: reportId, p_original_filename: file.name, p_mime_type: file.type,
        p_size_bytes: file.size, p_sha256: sha256,
        p_description: String(formData.get("description") ?? ""), p_sensitivity: "normal",
      });
      if (reserveError) throw reserveError;
      const reserved = (reservation as Array<{ attachment_id: string; storage_path: string }> | null)?.[0];
      if (!reserved) throw new Error("reservation_missing");
      const { error: uploadError } = await supabase.storage.from("evidence").upload(reserved.storage_path, file, { upsert: false, contentType: file.type });
      if (uploadError) throw uploadError;
      const { error: finalizeError } = await supabase.rpc("finalize_report_attachment", { p_attachment_id: reserved.attachment_id });
      if (finalizeError) throw finalizeError;
      setMessage("Evidência enviada e registrada com SHA-256.");
      router.refresh();
    } catch {
      setMessage("Não foi possível concluir o upload privado.");
    } finally { setPending(false); }
  }

  return <form action={upload} className="grid gap-3 rounded-xl border bg-white p-5">
    <h2 className="text-lg font-bold">Adicionar evidência</h2>
    <input type="file" name="file" required accept=".jpg,.jpeg,.png,.webp,.pdf,.mp3,.m4a,.mp4,.docx,.xlsx" />
    <input name="description" maxLength={300} className="min-h-11 rounded-lg border px-3" placeholder="Descrição opcional, sem PII desnecessária" />
    <button disabled={pending} className="min-h-11 rounded-lg bg-forest px-4 font-bold text-white disabled:opacity-60">{pending ? "Enviando…" : "Enviar ao bucket privado"}</button>
    {message && <p role="status" className="text-sm">{message}</p>}
  </form>;
}

export function EvidenceDownloadButton({ path, filename }: { path: string; filename: string }) {
  const [pending, setPending] = useState(false);
  async function download() {
    setPending(true);
    const { data, error } = await createClient().storage.from("evidence").createSignedUrl(path, 60, { download: filename });
    if (!error && data?.signedUrl) window.location.assign(data.signedUrl);
    setPending(false);
  }
  return <button type="button" onClick={download} disabled={pending} className="font-semibold text-forest underline">{pending ? "Preparando…" : "Baixar (link de 60 s)"}</button>;
}
