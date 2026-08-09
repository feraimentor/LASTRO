# Deployment, backup e recuperação

## Ambientes e fonte de verdade

Use projetos Supabase e variáveis independentes para `development`, `preview/staging` e `production`. Development nunca aponta para produção. Preview não envia e-mail real por padrão. Migrations versionadas são a única fonte do schema; alterações manuais no painel devem ser convertidas em migration antes de qualquer release.

Antes do deploy, execute `pnpm release:env`, `pnpm check`, o job `database` e a suíte E2E do CI. Configure Google OAuth com o callback HTTPS do ambiente, `EMAIL_PROVIDER=resend`, domínio/remetente verificado, cron com `CRON_SECRET`, bucket privado e políticas jurídicas vigentes. O primeiro Master nasce somente após login Google real correspondente a `MASTER_BOOTSTRAP_EMAIL`.

`vercel.json` agenda a atualização de compromissos às 03:00 UTC (00:00 em America/Sao_Paulo fora do horário de verão) e a drenagem de e-mails às 12:00 UTC (09:00). Os handlers aceitam o `GET` enviado pelo Vercel Cron, validam `Authorization: Bearer $CRON_SECRET` e preservam `POST` somente para reexecução operacional autenticada. O agendamento diário é compatível com Hobby; reduza o intervalo apenas depois de confirmar um plano que aceite frequências maiores.

## Backup independente do PostgreSQL

Use uma credencial restrita e uma máquina confiável com `pg_dump` da mesma major version do banco:

```powershell
$env:LASTRO_DATABASE_URL = "postgresql://..."
./scripts/backup-database.ps1 -TargetDirectory "D:\backups\lastro"
```

O script produz dump custom comprimido e checksum SHA-256. Armazene ambos fora do provedor primário, criptografados, com retenção e acesso auditado. Registre timestamp UTC, commit, migration mais recente, ambiente e operador.

## Inventário e backup do Storage

Gere o inventário autenticado sem expor a secret:

```powershell
pnpm storage:inventory > storage-inventory.json
```

O inventário registra buckets, paths, tamanhos e datas. Copie os objetos privados por API/S3 autenticada para armazenamento cifrado, preservando o path exato. Calcule checksums dos objetos e do inventário. O inventário sozinho não é backup.

## Restore em ambiente não produtivo

Crie um banco vazio isolado e execute:

```powershell
./scripts/restore-database.ps1 -BackupFile "D:\backups\lastro\lastro.dump" -TargetDatabaseUrl "postgresql://staging..." -TargetEnvironment staging
```

O script recusa `production` e URLs que pareçam produtivas. Depois do banco:

1. restaure objetos Storage no bucket privado e nos paths originais;
2. aplique somente migrations posteriores ao dump;
3. execute `pnpm legal:verify`, migrations/seed idempotentes e pgTAP;
4. confirme que toda tabela exposta usa RLS e toda view comunitária é `security_invoker`;
5. valide login, reaceite jurídico, identidade protegida, busca, case access e download autorizado;
6. compare contagens por entidade e checksums do Storage;
7. registre RPO, RTO, evidência e resultado no painel `/admin/seguranca`.

O script `scripts/run-local-restore-drill-wsl.sh` reproduz o exercício em bancos locais descartáveis. Em 2026-08-09, o drill local restaurou o banco em 3 segundos, encontrou três versões jurídicas vigentes, zero tabela pública sem RLS, zero view insegura e zero objeto no Storage sintético; checksum do dump: `fd4566fe80400919833e021cbbb219c3042a22b2800bbbdc6a88c56bac470326`. Isso valida o procedimento local, não substitui um restore de staging com objetos reais.

## Reconstrução do app pelo Git

Faça checkout do commit registrado no backup, instale com `pnpm install --frozen-lockfile`, valide os documentos jurídicos, gere o build e aplique migrations controladas. Recrie somente secrets pelo cofre do ambiente; nunca restaure secrets de arquivos de backup.

## Resposta a incidentes

Fluxo obrigatório: detectar → conter → investigar → corrigir → recuperar → documentar. Registre severidade, sistemas, categorias de dados, contenção, remediação, decisão de notificação e fechamento em `/admin/seguranca`. Preserve evidências com acesso mínimo. Nunca copie tokens, documentos ou conteúdo sensível integral para logs. Avaliação e comunicação legal devem seguir a política vigente e orientação jurídica aplicável.

## Gate

Backup sem restore testado não passa o release gate. Produção continua bloqueada até existir restore real em staging, Storage real verificado, OAuth/Resend/cron testados, ambientes separados e monitoramento hospedado observado.
