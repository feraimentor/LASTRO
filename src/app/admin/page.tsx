import Link from "next/link";
import { KpiCard } from "@/components/record-cards";
import { requirePermission } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";
import { AdminHeader } from "./_components";

export default async function AdminPage() {
  await requirePermission("admins.manage");
  const supabase = await createClient();
  const [pendingResult, flagsResult, importsResult, incidentsResult] = await Promise.all([
    supabase.from("verification_requests").select("id", { count: "exact", head: true }).in("state", ["pending", "needs_information"]),
    supabase.from("content_flags").select("id", { count: "exact", head: true }).in("state", ["open", "reviewing"]),
    supabase.from("import_staging_items").select("id", { count: "exact", head: true }).eq("state", "pending_review"),
    supabase.from("security_incidents").select("id", { count: "exact", head: true }).neq("status", "closed"),
  ]);
  return <main>
    <AdminHeader title="Centro de governança" description="Filas administrativas separadas, permissões granulares e decisões auditáveis."/>
    <section className="mt-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
      <KpiCard label="Verificações" value={pendingResult.count ?? 0} note="Pendentes ou em análise"/>
      <KpiCard label="Sinalizações" value={flagsResult.count ?? 0} note="Abertas ou em análise"/>
      <KpiCard label="Itens de importação" value={importsResult.count ?? 0} note="Aguardando curadoria"/>
      <KpiCard label="Incidentes" value={incidentsResult.count ?? 0} note="Não encerrados"/>
    </section>
    <Link href="/admin/auditoria" className="mt-6 inline-block font-semibold text-forest">Consultar trilha administrativa →</Link>
  </main>;
}
