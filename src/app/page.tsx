import Link from "next/link";
import { ArrowRight, FileClock, Layers3, LockKeyhole, Scale } from "lucide-react";

const pillars = [
  { icon: FileClock, title: "Memória preservada", text: "Relatos, complementos, evidências e prazos permanecem em ordem cronológica." },
  { icon: Layers3, title: "Problemas agrupados", text: "Um problema coletivo pode reunir relatos diferentes sem apagar a experiência individual." },
  { icon: Scale, title: "Contraditório claro", text: "Retornos externos, respostas oficiais e avaliação do morador aparecem com autoria e origem distintas." },
  { icon: LockKeyhole, title: "Comunidade privada", text: "Somente pessoas autorizadas e com vínculo verificado acessam o conteúdo comunitário." },
];

export default function Home() {
  return <main>
    <section className="brick-texture text-white">
      <div className="mx-auto max-w-6xl px-5 py-5 flex items-center justify-between">
        <span className="text-xl font-bold tracking-[.18em]">LASTRO</span>
        <Link href="/login" className="rounded-full bg-white px-5 py-2.5 font-semibold text-brick hover:bg-sand">Entrar</Link>
      </div>
      <div className="mx-auto max-w-6xl px-5 py-16 sm:py-24 grid gap-12 lg:grid-cols-[1.2fr_.8fr] lg:items-end">
        <div>
          <p className="mb-4 font-semibold uppercase tracking-[.16em] text-[#f0ded3]">Condomínio Alto Icaraí</p>
          <h1 className="max-w-4xl text-4xl font-bold leading-tight sm:text-6xl">Memória comunitária para problemas que precisam de acompanhamento.</h1>
          <p className="mt-6 max-w-2xl text-lg text-[#f6eee9]">O LASTRO organiza demandas, preserva evidências, registra respostas e acompanha compromissos — sem depender da participação de uma gestão específica.</p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/login" className="inline-flex min-h-12 items-center gap-2 rounded-lg bg-white px-5 py-3 font-bold text-brick">Acessar com Google <ArrowRight size={18} /></Link>
            <Link href="/legal" className="inline-flex min-h-12 items-center rounded-lg border border-white/60 px-5 py-3 font-semibold text-white">Conhecer as políticas</Link>
          </div>
        </div>
        <aside className="rounded-2xl border border-white/20 bg-[#2e302c]/50 p-6 backdrop-blur-sm" aria-label="Aviso importante">
          <p className="font-bold">Ferramenta comunitária privada</p>
          <p className="mt-2 text-sm text-[#f6eee9]">O LASTRO documenta e acompanha. Não substitui canais de emergência, autoridades, assembleias ou notificações formais.</p>
        </aside>
      </div>
    </section>
    <section className="mx-auto max-w-6xl px-5 py-16" aria-labelledby="como-funciona">
      <p className="font-semibold uppercase tracking-[.14em] text-forest">Seriedade, organização e transparência</p>
      <h2 id="como-funciona" className="mt-2 text-3xl font-bold">Um registro que continua útil com o passar do tempo</h2>
      <div className="mt-8 grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {pillars.map(({ icon: Icon, title, text }) => <article key={title} className="rounded-2xl border border-[#d9d2cb] bg-white p-5 shadow-sm">
          <Icon className="text-forest" aria-hidden="true" />
          <h3 className="mt-4 text-lg font-bold">{title}</h3><p className="mt-2 text-sm text-[#555750]">{text}</p>
        </article>)}
      </div>
    </section>
    <footer className="border-t border-[#d9d2cb] bg-sand">
      <div className="mx-auto max-w-6xl px-5 py-8 flex flex-col gap-3 sm:flex-row sm:justify-between">
        <p className="font-semibold">LASTRO — memória, proveniência e responsabilidade.</p>
        <Link href="/legal" className="text-forest underline">Documentos jurídicos</Link>
      </div>
    </footer>
  </main>;
}
