import Link from "next/link";

export function OnboardingShell({ step, title, description, children }: { step: number; title: string; description: string; children: React.ReactNode }) {
  return <main className="min-h-screen bg-sand px-5 py-8">
    <div className="mx-auto max-w-3xl">
      <div className="flex items-center justify-between"><Link href="/" className="font-bold tracking-[.16em] text-brick">LASTRO</Link><span className="text-sm text-[#686a63]">Etapa {step} de 4</span></div>
      <div className="mt-6 h-2 overflow-hidden rounded-full bg-white" aria-label={`Etapa ${step} de 4`}><div className="h-full bg-forest" style={{ width: `${step * 25}%` }} /></div>
      <header className="mt-10"><h1 className="text-3xl font-bold">{title}</h1><p className="mt-3 max-w-2xl text-[#5d5f58]">{description}</p></header>
      <section className="mt-8">{children}</section>
    </div>
  </main>;
}
