import Link from "next/link";
import { CopyUserIdButton } from "@/components/copy-user-id-button";
import { ReauthenticateButton } from "@/components/reauthenticate-button";
import { requirePermission } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";
import { AdminEmpty, AdminHeader } from "../_components";
import { setSuspensionAction } from "../moradores/actions";

type DirectoryUser = {
  user_id: string;
  email: string | null;
  display_name: string | null;
  first_name: string | null;
  last_name: string | null;
  access_state: string;
  onboarding_step: string;
  relation_types: string[];
  block_labels: string[];
  unit_labels: string[];
  latest_verification_request_id: string | null;
  latest_verification_state: string | null;
  requested_relation_type: string | null;
  requested_block_label: string | null;
  requested_unit_label: string | null;
  role_slugs: string[];
  permission_slugs: string[];
  created_at: string;
  last_sign_in_at: string | null;
};

const onboardingLabels: Record<string, string> = {
  legal: "Aceite jurídico pendente",
  profile: "Perfil pendente",
  unit: "Vínculo ainda não solicitado",
  verification: "Informações adicionais solicitadas",
  pending: "Verificação pendente",
  complete: "Onboarding concluído",
};

const accessLabels: Record<string, string> = {
  onboarding: "Em onboarding",
  pending_verification: "Aguardando verificação",
  active: "Ativo",
  link_ended: "Vínculo encerrado",
  suspended: "Suspenso",
  official: "Conta oficial",
  case_restricted: "Acesso restrito a caso",
};

const relationLabels: Record<string, string> = {
  resident_owner: "Proprietário morador",
  nonresident_owner: "Proprietário não residente",
  tenant: "Inquilino",
  authorized_resident: "Morador autorizado",
  owner_representative: "Representante do proprietário",
};

const roleLabels: Record<string, string> = {
  resident: "Morador",
  official: "Conta oficial",
  moderator: "Moderador",
  administrator: "Administrador",
  master: "Master",
};

function firstParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] ?? "" : value ?? "";
}

function formatDate(value: string | null) {
  return value ? new Intl.DateTimeFormat("pt-BR", { dateStyle: "short", timeStyle: "short", timeZone: "America/Sao_Paulo" }).format(new Date(value)) : "Nunca";
}

export default async function UsersPage({ searchParams }: { searchParams: Promise<{ q?: string | string[] }> }) {
  await requirePermission("admins.manage");
  await requirePermission("private_data.view");

  const query = firstParam((await searchParams).q).trim().slice(0, 120);
  const supabase = await createClient();
  const [{ data, error }, { data: canSuspend }] = await Promise.all([
    supabase.rpc("admin_search_users", { p_query: query || null, p_limit: 50 }),
    supabase.rpc("current_user_has_permission", { p_permission: "residents.suspend" }),
  ]);

  if (error) throw new Error("Não foi possível consultar o diretório administrativo de usuários.");
  const users = (data ?? []) as DirectoryUser[];

  return (
    <main>
      <AdminHeader title="Usuários" description="Localize identidades por nome, e-mail, bloco, unidade ou UUID. E-mail e demais dados privados permanecem restritos às permissões administrativas atuais." />

      <form method="get" className="mt-6 grid gap-3 rounded-xl border bg-white p-5 sm:grid-cols-[1fr_auto_auto] sm:items-end" role="search">
        <label className="grid gap-1 text-sm font-semibold" htmlFor="user-search">
          Buscar usuário
          <input id="user-search" name="q" defaultValue={query} maxLength={120} className="min-h-11 rounded-lg border border-[#aaa59e] px-3 font-normal" placeholder="Nome, e-mail, bloco, unidade ou UUID" />
        </label>
        <button className="min-h-11 rounded-lg bg-forest px-5 font-bold text-white">Buscar</button>
        <Link href="/admin/usuarios" className="inline-flex min-h-11 items-center justify-center rounded-lg border border-[#aaa59e] px-5 font-bold">Limpar</Link>
      </form>

      <div className="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm text-[#62645e]">
        <p>{users.length} {users.length === 1 ? "usuário encontrado" : "usuários encontrados"}{users.length === 50 ? " (limite da página)" : ""}.</p>
        {canSuspend ? <ReauthenticateButton nextPath={`/admin/usuarios${query ? `?q=${encodeURIComponent(query)}` : ""}`} /> : null}
      </div>

      {users.length ? (
        <div className="mt-6 space-y-5">
          {users.map((user) => {
            const fullName = [user.first_name, user.last_name].filter(Boolean).join(" ");
            const relations = user.relation_types.length ? user.relation_types : user.requested_relation_type ? [user.requested_relation_type] : [];
            const blocks = user.block_labels.length ? user.block_labels : user.requested_block_label ? [user.requested_block_label] : [];
            const units = user.unit_labels.length ? user.unit_labels : user.requested_unit_label ? [user.requested_unit_label] : [];
            const verificationOpen = user.latest_verification_request_id && ["pending", "needs_information"].includes(user.latest_verification_state ?? "");
            const suspended = user.access_state === "suspended";
            const isMaster = user.role_slugs.includes("master");

            return (
              <article key={user.user_id} id={`user-${user.user_id}`} className="rounded-xl border bg-white p-5 shadow-sm">
                <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_auto]">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-xl font-bold">{user.display_name ?? (fullName || "Perfil ainda não preenchido")}</h2>
                      <span className={`rounded-full px-2.5 py-1 text-xs font-bold ${suspended ? "bg-[#fbeaea] text-danger" : user.access_state === "active" ? "bg-forest-soft text-forest" : "bg-sand text-[#5b5148]"}`}>
                        {accessLabels[user.access_state] ?? user.access_state}
                      </span>
                    </div>
                    <p className="mt-1 break-all text-sm text-[#52544f]">{user.email ?? "E-mail indisponível"}</p>
                    <p className="mt-3 break-all font-mono text-xs text-[#52544f]" aria-label={`UUID ${user.user_id}`}>{user.user_id}</p>
                  </div>
                  <CopyUserIdButton userId={user.user_id} />
                </div>

                <dl className="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                  <div className="rounded-lg bg-sand p-3"><dt className="text-xs font-bold uppercase tracking-wide text-[#666159]">Onboarding</dt><dd className="mt-1 text-sm">{onboardingLabels[user.onboarding_step] ?? user.onboarding_step}</dd></div>
                  <div className="rounded-lg bg-sand p-3"><dt className="text-xs font-bold uppercase tracking-wide text-[#666159]">Vínculo</dt><dd className="mt-1 text-sm">{relations.length ? relations.map((item) => relationLabels[item] ?? item).join(", ") : "Não informado"}</dd></div>
                  <div className="rounded-lg bg-sand p-3"><dt className="text-xs font-bold uppercase tracking-wide text-[#666159]">Bloco e unidade</dt><dd className="mt-1 text-sm">{blocks.length || units.length ? `${blocks.join(", ") || "—"} · ${units.join(", ") || "—"}` : "Não informado"}</dd></div>
                  <div className="rounded-lg bg-sand p-3"><dt className="text-xs font-bold uppercase tracking-wide text-[#666159]">Último acesso</dt><dd className="mt-1 text-sm">{formatDate(user.last_sign_in_at)}</dd></div>
                </dl>

                <section className="mt-5">
                  <h3 className="text-sm font-bold">Papéis atuais</h3>
                  <div className="mt-2 flex flex-wrap gap-2">{user.role_slugs.length ? user.role_slugs.map((role) => <span key={role} className="rounded-full bg-[#262d29] px-3 py-1 text-xs font-bold text-white">{roleLabels[role] ?? role}</span>) : <span className="text-sm text-[#62645e]">Nenhum papel administrativo explícito.</span>}</div>
                </section>

                <details className="mt-4 rounded-lg border px-4 py-3">
                  <summary className="cursor-pointer font-bold">Permissões efetivas ({user.permission_slugs.length})</summary>
                  <div className="mt-3 flex flex-wrap gap-2">{user.permission_slugs.length ? user.permission_slugs.map((permission) => <code key={permission} className="rounded bg-sand px-2 py-1 text-xs">{permission}</code>) : <span className="text-sm text-[#62645e]">Nenhuma permissão administrativa.</span>}</div>
                </details>

                <div className="mt-5 flex flex-wrap gap-2 border-t pt-4">
                  {verificationOpen ? <Link href={`/admin/verificacoes#request-${user.latest_verification_request_id}`} className="inline-flex min-h-10 items-center rounded-lg bg-forest px-4 text-sm font-bold text-white">Verificar vínculo</Link> : <Link href="/admin/verificacoes" className="inline-flex min-h-10 items-center rounded-lg border border-[#aaa59e] px-4 text-sm font-bold">Ver verificações</Link>}
                  <Link href={`/admin/administradores?user=${encodeURIComponent(user.user_id)}`} className="inline-flex min-h-10 items-center rounded-lg border border-[#aaa59e] px-4 text-sm font-bold">Administrar papéis</Link>
                </div>

                {canSuspend && !isMaster ? (
                  <form action={setSuspensionAction} className="mt-3 grid gap-2 sm:grid-cols-[1fr_auto]">
                    <input type="hidden" name="target_user_id" value={user.user_id} />
                    <input name="reason" required minLength={5} maxLength={500} className="min-h-10 rounded-lg border border-[#aaa59e] px-3" placeholder={suspended ? "Motivo para restaurar o acesso" : "Motivo para suspender o acesso"} />
                    <button name="suspend" value={suspended ? "false" : "true"} className={`min-h-10 rounded-lg px-4 text-sm font-bold text-white ${suspended ? "bg-forest" : "bg-danger"}`}>{suspended ? "Restaurar acesso" : "Suspender acesso"}</button>
                  </form>
                ) : null}
              </article>
            );
          })}
        </div>
      ) : <AdminEmpty>Nenhum usuário corresponde aos filtros informados.</AdminEmpty>}
    </main>
  );
}
