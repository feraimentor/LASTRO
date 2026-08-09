import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";

export const legalDocuments = [
  { key: "notifications_communication", slug: "notificacoes-comunicacao", title: "Política de Notificações e Comunicação" },
  { key: "responsible_use_moderation", slug: "uso-responsavel-moderacao", title: "Política de Uso Responsável, Moderação e Proteção contra Abusos" },
  { key: "privacy_terms", slug: "privacidade-termos", title: "Política de Privacidade, LGPD e Termos de Uso" },
] as const;

export type LegalDocument = (typeof legalDocuments)[number];

export function canonicalizeLegalMarkdown(source: string) {
  return `${source.normalize("NFC").replace(/\r\n?/g, "\n").trimEnd()}\n`;
}
export async function getLegalDocument(slug: string) {
  const metadata = legalDocuments.find((document) => document.slug === slug);
  if (!metadata) return null;
  const file = path.join(process.cwd(), "legal", metadata.key, "1.0.md");
  const markdown = canonicalizeLegalMarkdown(await readFile(file, "utf8"));
  const hash = createHash("sha256").update(markdown, "utf8").digest("hex");
  return { ...metadata, version: "1.0", markdown, hash, downloadPath: `/legal/${metadata.slug}-v1.0.docx` };
}
