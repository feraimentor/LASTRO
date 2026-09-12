# LASTRO

Memória compartilhada e verificável do Condomínio Alto Icaraí. A V1 organiza relatos individuais em problemas coletivos sem apagar autoria, histórico, contraditório ou proveniência.

## Stack

- Next.js 16.3, React 19, TypeScript strict e Tailwind CSS 4;
- Supabase Auth (somente Google), PostgreSQL com RLS e Storage privado;
- Zod, React Hook Form, Vitest e Playwright;
- DOCX jurídico determinístico e templates CSV/XLSX de importação histórica.

Node.js 20.9 ou superior é obrigatório; o projeto fixa Node 22 em `.nvmrc` e pnpm 11.16.0 em `package.json`.

## Execução local

1. Copie `.env.example` para `.env.local` e preencha as chaves locais.
2. Inicie Docker Desktop.
3. Rode `pnpm install --frozen-lockfile`.
4. Rode `pnpm exec supabase start` e depois `pnpm exec supabase db reset`.
5. No Supabase local/hospedado, habilite Google OAuth e cadastre `/auth/callback` como redirect permitido.
6. Rode `pnpm dev` e abra `http://localhost:3000`.

Não use `SUPABASE_SECRET_KEY` no navegador. O primeiro Master só é concedido após login Google autenticado do e-mail configurado em `MASTER_BOOTSTRAP_EMAIL`; a concessão é idempotente e auditada.

## Comandos

| Comando | Finalidade |
|---|---|
| `pnpm dev` | servidor local |
| `pnpm lint` | ESLint |
| `pnpm typecheck` | TypeScript sem emissão |
| `pnpm test` | testes unitários |
| `pnpm test:e2e` | Playwright |
| `pnpm legal:generate` | regenera hashes, seed e DOCX jurídicos |
| `pnpm legal:verify` | verifica sincronismo jurídico |
| `pnpm storage:inventory` | inventário autenticado dos buckets |
| `pnpm release:env` | valida variáveis mínimas de produção |
| `pnpm build` | build de produção |
| `pnpm build:cloudflare` | gera o Worker via OpenNext |
| `pnpm deploy:cloudflare` | gera e publica o Worker |
| `pnpm check` | lint + tipos + unit + build |

## Estrutura

- `src/app`: rotas públicas, onboarding, comunidade, admin e cron;
- `src/lib`: fronteiras Supabase, validações, e-mail e políticas de upload;
- `supabase/migrations`: schema, funções, RLS, grants, views e Storage;
- `supabase/seed.sql`: dados exclusivamente estruturais;
- `legal`: fonte canônica versionada das três políticas;
- `public/legal`: downloads DOCX gerados;
- `public/templates`: templates de importação sem dados reais;
- `docs`: arquitetura, dados, RLS, jurídico, moderação, importação, operação e testes;
- `docs/IMPLEMENTATION_STATUS.md`: ledger requisito a requisito; é a fonte de verdade sobre prontidão.

## Segurança e operação

Rotas comunitárias exigem usuário autenticado, três aceites vigentes, perfil completo, vínculo aprovado e acesso ativo. Rotas administrativas revalidam permissão granular no banco. Views comunitárias usam `security_invoker`; PII fica fora da projeção comunitária. Evidências ficam no bucket privado `evidence`, com path sem PII e autorização relacional.

Os endpoints `GET|POST /api/cron/commitments` e `GET|POST /api/cron/notifications` exigem `Authorization: Bearer $CRON_SECRET`, geram correlation ID e registram resultado sanitizado. `wrangler.jsonc` agenda ambos diariamente em UTC no Cloudflare Workers; em produção, o adapter de e-mail exige `EMAIL_PROVIDER=resend`, chave e remetente verificado.

O ambiente produtivo está em `https://lastro.feraimentor.workers.dev`. Variáveis públicas ficam em `wrangler.jsonc`; `SUPABASE_SECRET_KEY`, `MASTER_BOOTSTRAP_EMAIL`, `CRON_SECRET`, `RESEND_API_KEY` e demais credenciais devem ser gravadas somente como secrets do Worker.

Consulte `docs/DEPLOYMENT_AND_RECOVERY.md` antes de preview ou produção. Este repositório não deve ser considerado pronto para produção enquanto houver itens V1 sem estado `ACCEPTED` no ledger.
