import { ReauthenticateButton } from "@/components/reauthenticate-button";
import { requirePermission } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";
import { AdminHeader, DataTable } from "../_components";
import { setPermissionOverrideAction, setUserRoleAction } from "./actions";
import { z } from "zod";

const input = "min-h-11 rounded-lg border border-[#aaa59e] bg-white px-3";

export default async function Page({ searchParams }: { searchParams: Promise<{ user?: string | string[] }> }) {
  await requirePermission("admins.manage");
  const supabase = await createClient();
  const requestedUser = (await searchParams).user;
  const candidateUserId = Array.isArray(requestedUser) ? requestedUser[0] : requestedUser;
  const parsedUserId = z.string().uuid().safeParse(candidateUserId);
  const selectedUserId = parsedUserId.success ? parsedUserId.data : "";
  const [{ data: assignments }, { data: permissions }, { data: recent }] = await Promise.all([
    supabase.from("user_roles").select("id,user_id,granted_at,revoked_at,roles(slug,name,level)").order("granted_at", { ascending: false }),
    supabase.from("permissions").select("slug,description").order("slug"),
    supabase.rpc("current_session_is_recent"),
  ]);
  return <main>
    <AdminHeader title="Administradores e permissões" description="Grants e denies são consultados no banco em cada operação. Autoelevação e alteração de nível superior são bloqueadas." />
    {selectedUserId ? <p className="mt-5 rounded-lg bg-forest-soft p-4 text-sm">Usuário selecionado: <code className="break-all font-bold">{selectedUserId}</code></p> : null}
    <section className="mt-6 rounded-xl border bg-white p-5">
      <h2 className="text-lg font-bold">Autenticação crítica</h2>
      <p className="my-3 text-sm text-[#62645e]">Sessão recente: <b>{recent ? "sim" : "não"}</b>. Alterações abaixo exigem confirmação Google nos últimos 15 minutos.</p>
      <ReauthenticateButton nextPath="/admin/administradores" />
    </section>
    <div className="mt-6 grid gap-5 xl:grid-cols-2">
      <form action={setUserRoleAction} className="grid gap-3 rounded-xl border bg-white p-5">
        <h2 className="text-lg font-bold">Conceder ou revogar papel</h2>
        <input className={input} name="target_user_id" required placeholder="UUID do usuário" defaultValue={selectedUserId} />
        <select className={input} name="role_slug" defaultValue="moderator"><option value="resident">Morador</option><option value="official">Conta oficial</option><option value="moderator">Moderador</option><option value="administrator">Administrador</option><option value="master">Master</option></select>
        <select className={input} name="action" defaultValue="grant"><option value="grant">Conceder</option><option value="revoke">Revogar</option></select>
        <input className={input} name="reason" required minLength={5} maxLength={500} placeholder="Motivo obrigatório" />
        <button className="min-h-11 rounded-lg bg-forest px-4 font-bold text-white">Aplicar papel</button>
      </form>
      <form action={setPermissionOverrideAction} className="grid gap-3 rounded-xl border bg-white p-5">
        <h2 className="text-lg font-bold">Exceção individual de permissão</h2>
        <input className={input} name="target_user_id" required placeholder="UUID do usuário" defaultValue={selectedUserId} />
        <select className={input} name="permission_slug">{permissions?.map((permission) => <option key={permission.slug} value={permission.slug}>{permission.slug}</option>)}</select>
        <select className={input} name="effect" defaultValue="grant"><option value="grant">Conceder</option><option value="deny">Negar explicitamente</option><option value="revoke">Revogar exceção</option></select>
        <input className={input} name="reason" required minLength={5} maxLength={500} placeholder="Motivo obrigatório" />
        <button className="min-h-11 rounded-lg bg-forest px-4 font-bold text-white">Aplicar exceção</button>
      </form>
    </div>
    <DataTable headers={["Usuário", "Papel", "Nível", "Estado"]} rows={(assignments ?? []).map((assignment) => [assignment.user_id, assignment.roles?.[0]?.name, assignment.roles?.[0]?.level, assignment.revoked_at ? "Revogado" : "Ativo"])} />
  </main>;
}
