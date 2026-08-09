import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Download } from "lucide-react";
import { LegalMarkdown } from "@/components/legal-markdown";
import { getLegalDocument, legalDocuments } from "@/lib/legal-documents";

export function generateStaticParams() { return legalDocuments.map(({ slug }) => ({ slug })); }

type LegalPageProps = { params: Promise<{ slug: string }> };

export async function generateMetadata({ params }: LegalPageProps): Promise<Metadata> {
  const { slug } = await params;
  const document = await getLegalDocument(slug);
  return { title: document?.title ?? "Documento jurídico" };
}

export default async function LegalPage({ params }: LegalPageProps) {
  const { slug } = await params;
  const document = await getLegalDocument(slug);
  if (!document) notFound();
  return <main className="min-h-screen bg-[#f8f6f3]">
    <header className="sticky top-0 z-10 border-b border-[#d8d0c8] bg-white/95 backdrop-blur">
      <div className="mx-auto flex max-w-4xl items-center justify-between gap-4 px-5 py-3">
        <Link href="/legal" className="font-semibold text-forest">← Políticas</Link>
        <a href={document.downloadPath} className="inline-flex items-center gap-2 rounded-lg bg-forest px-3 py-2 font-semibold text-white"><Download size={16} /> <span className="hidden sm:inline">Baixar</span> .docx</a>
      </div>
    </header>
    <article className="mx-auto max-w-4xl px-5 py-10 sm:py-14">
      <div className="mb-8 rounded-xl border border-[#d8d0c8] bg-white p-4 text-sm text-[#5d5f58]">
        <p><strong>Versão:</strong> {document.version}</p>
        <p className="mt-1 break-all"><strong>SHA-256:</strong> {document.hash}</p>
      </div>
      <LegalMarkdown markdown={document.markdown} />
    </article>
  </main>;
}
