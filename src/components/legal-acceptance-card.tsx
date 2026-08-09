import Link from "next/link";
import { FileText } from "lucide-react";

export function LegalAcceptanceCard({ title, slug, value }: { title: string; slug: string; value: string }) {
  return <article className="rounded-xl border border-[#d8d0c8] bg-white p-5">
    <div className="flex items-start gap-3"><FileText className="mt-1 shrink-0 text-forest" aria-hidden="true" /><div><h2 className="font-bold">{title}</h2><Link href={`/legal/${slug}`} target="_blank" className="mt-1 inline-block text-sm font-semibold text-info underline">Ler o documento integral</Link></div></div>
    <label className="mt-5 flex min-h-11 cursor-pointer items-start gap-3 rounded-lg bg-forest-soft p-3">
      <input className="mt-1 size-5 shrink-0 accent-[#3e6652]" type="checkbox" name="accept" value={value} required />
      <span>Li e aceito esta política, na versão vigente.</span>
    </label>
  </article>;
}
