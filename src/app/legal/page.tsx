import type { Metadata } from "next";
import Link from "next/link";
import { Download, FileCheck2 } from "lucide-react";
import { legalDocuments } from "@/lib/legal-documents";

export const metadata: Metadata = { title: "Documentos jurídicos" };

export default function LegalIndex() {
  return <main className="min-h-screen bg-sand">
    <header className="brick-texture text-white"><div className="mx-auto max-w-4xl px-5 py-10">
      <Link href="/" className="text-sm font-semibold">← LASTRO</Link>
      <h1 className="mt-5 text-3xl font-bold">Documentos jurídicos</h1>
      <p className="mt-2 max-w-2xl text-[#f6eee9]">As versões vigentes são públicas, integrais e disponíveis para download. O acesso comunitário exige aceite separado dos três documentos.</p>
    </div></header>
    <section className="mx-auto max-w-4xl px-5 py-10 grid gap-4">
      {legalDocuments.map((document) => <article key={document.key} className="rounded-2xl border border-[#d8d0c8] bg-white p-6 shadow-sm">
        <FileCheck2 className="text-forest" aria-hidden="true" />
        <h2 className="mt-3 text-xl font-bold">{document.title}</h2>
        <p className="mt-1 text-sm text-[#66685f]">Versão 1.0 • publicada em 09 de agosto de 2026</p>
        <div className="mt-5 flex flex-wrap gap-3">
          <Link className="rounded-lg bg-forest px-4 py-2.5 font-semibold text-white" href={`/legal/${document.slug}`}>Ler documento</Link>
          <a className="inline-flex items-center gap-2 rounded-lg border border-forest px-4 py-2.5 font-semibold text-forest" href={`/legal/${document.slug}-v1.0.docx`}><Download size={17} /> Baixar .docx</a>
        </div>
      </article>)}
    </section>
  </main>;
}
