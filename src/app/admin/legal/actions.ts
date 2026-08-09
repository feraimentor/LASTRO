"use server";

import { createHash } from "node:crypto";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requirePermission } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";

const draftSchema = z.object({
  document_key: z.enum(["notifications_communication", "responsible_use_moderation", "privacy_terms"]),
  version: z.string().trim().min(1).max(30),
  content_markdown: z.string().trim().min(100),
  requires_reacceptance: z.string().optional(),
  download_path: z.string().trim().max(300).optional(),
});

export async function createLegalDraftAction(formData: FormData) {
  await requirePermission("legal_documents.manage");
  const data = draftSchema.parse(Object.fromEntries(formData));
  const canonical = data.content_markdown.replace(/\r\n/g, "\n").normalize("NFC");
  const hash = createHash("sha256").update(canonical, "utf8").digest("hex");
  const supabase = await createClient();
  const { error } = await supabase.rpc("create_legal_draft", {
    p_document_key: data.document_key,
    p_version: data.version,
    p_content_markdown: canonical,
    p_content_hash_sha256: hash,
    p_requires_reacceptance: data.requires_reacceptance === "on",
    p_download_path: data.download_path || null,
  });
  if (error) throw new Error(error.message);
  revalidatePath("/admin/legal");
}

const publishSchema = z.object({
  version_id: z.string().uuid(),
  effective_at: z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/),
  download_path: z.string().trim().min(3).max(300),
});

export async function publishLegalVersionAction(formData: FormData) {
  await requirePermission("legal_documents.manage");
  const data = publishSchema.parse(Object.fromEntries(formData));
  const effectiveAt = new Date(`${data.effective_at}:00-03:00`).toISOString();
  const supabase = await createClient();
  const { error } = await supabase.rpc("publish_legal_version", {
    p_version_id: data.version_id,
    p_effective_at: effectiveAt,
    p_download_path: data.download_path,
  });
  if (error) throw new Error(error.message === "recent_authentication_required" ? "Confirme novamente sua conta Google antes da publicação." : error.message);
  revalidatePath("/admin/legal");
}
