import Link from "next/link";
import { Bell, ChartNoAxesColumn, CircleUserRound, ClipboardList, House, ListChecks, Plus, Search } from "lucide-react";

const links = [
  ["/dashboard", "Início", House], ["/problemas", "Problemas", Search], ["/registrar", "Registrar", Plus],
  ["/minhas-demandas", "Meus relatos", ClipboardList], ["/indicadores", "Indicadores", ChartNoAxesColumn],
] as const;

export function CommunityShell({ children, admin = false }: { children: React.ReactNode; admin?: boolean }) {
  return <div className="min-h-screen bg-[#f8f6f3] pb-24 md:pb-0">
    <header className="sticky top-0 z-20 border-b border-[#ded8d1] bg-white/95 backdrop-blur">
      <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-3">
        <Link href="/dashboard" className="font-bold tracking-[.18em] text-brick">LASTRO</Link>
        <nav className="hidden items-center gap-1 md:flex" aria-label="Navegação principal">
          {links.map(([href, label]) => <Link key={href} href={href} className="rounded-lg px-3 py-2 text-sm font-medium hover:bg-sand">{label}</Link>)}
          {admin && <Link href="/admin" className="rounded-lg px-3 py-2 text-sm font-semibold text-brick hover:bg-sand">Administração</Link>}
        </nav>
        <div className="flex gap-2"><Link href="/notificacoes" aria-label="Notificações" className="rounded-full p-2 hover:bg-sand"><Bell size={20}/></Link><Link href="/perfil" aria-label="Perfil" className="rounded-full p-2 hover:bg-sand"><CircleUserRound size={20}/></Link></div>
      </div>
    </header>
    {children}
    <nav className="fixed inset-x-0 bottom-0 z-30 grid grid-cols-5 border-t border-[#d8d2ca] bg-white px-1 py-1 md:hidden" aria-label="Navegação móvel">
      {links.map(([href, label, Icon]) => <Link key={href} href={href} className="flex min-h-14 flex-col items-center justify-center gap-1 rounded text-[.67rem] font-medium"><Icon size={19}/><span>{label}</span></Link>)}
    </nav>
  </div>;
}

export function PageHeader({ eyebrow, title, description, action }: { eyebrow?: string; title: string; description?: string; action?: React.ReactNode }) {
  return <header className="flex flex-col gap-4 border-b border-[#ddd6ce] pb-6 sm:flex-row sm:items-end sm:justify-between">
    <div>{eyebrow && <p className="text-xs font-bold uppercase tracking-[.16em] text-forest">{eyebrow}</p>}<h1 className="mt-1 text-3xl font-bold tracking-tight">{title}</h1>{description && <p className="mt-2 max-w-2xl text-[#62645e]">{description}</p>}</div>{action}
  </header>;
}

export function EmptyState({ title, body, href, label }: { title: string; body: string; href?: string; label?: string }) {
  return <div className="rounded-2xl border border-dashed border-[#bdb5ac] bg-white p-10 text-center"><ListChecks className="mx-auto text-forest"/><h2 className="mt-4 text-xl font-bold">{title}</h2><p className="mx-auto mt-2 max-w-lg text-[#666861]">{body}</p>{href && <Link href={href} className="mt-5 inline-flex rounded-lg bg-forest px-4 py-2.5 font-semibold text-white">{label}</Link>}</div>;
}
