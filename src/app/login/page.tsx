import type { Metadata } from "next";
import Link from "next/link";
import { GoogleSignIn } from "@/components/google-sign-in";

export const metadata: Metadata = { title: "Entrar" };

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ next?: string }> }) {
  const { next } = await searchParams;
  const nextPath = next?.startsWith("/") && !next.startsWith("//") ? next : "/onboarding/legal";
  return <main className="brick-texture flex min-h-screen items-center justify-center px-5 py-10">
    <section className="w-full max-w-md rounded-2xl bg-white p-7 shadow-2xl sm:p-9" aria-labelledby="login-title">
      <Link href="/" className="text-sm font-semibold text-forest">← Voltar</Link>
      <p className="mt-8 font-bold tracking-[.18em] text-brick">LASTRO</p>
      <h1 id="login-title" className="mt-2 text-3xl font-bold">Acesse a comunidade</h1>
      <p className="mt-3 text-[#5d5f58]">O Google confirma sua identidade. O acesso às demandas depende também do aceite das políticas e da verificação do vínculo condominial.</p>
      <div className="mt-7"><GoogleSignIn nextPath={nextPath} /></div>
      <p className="mt-5 text-xs text-[#66685f]">Não há senha local. Ao continuar, você será direcionado ao Google e depois ao portão jurídico.</p>
      <Link href="/legal" className="mt-5 inline-block text-sm font-semibold text-forest underline">Ler políticas antes de entrar</Link>
    </section>
  </main>;
}
