# LASTRO

> Memória comunitária verificável para registrar, organizar e acompanhar problemas do Condomínio Alto Icaraí.

[![Aplicação](https://img.shields.io/badge/aplica%C3%A7%C3%A3o-acessar-275c4b)](https://lastro.feraimentor.workers.dev)
[![CI](https://github.com/feraimentor/LASTRO/actions/workflows/ci.yml/badge.svg)](https://github.com/feraimentor/LASTRO/actions/workflows/ci.yml)
[![Licença](https://img.shields.io/badge/licen%C3%A7a-propriet%C3%A1ria-b44f35)](LICENSE.md)

O LASTRO transforma relatos individuais em memória coletiva sem apagar autoria, histórico, contraditório ou proveniência. Ele ajuda moradores a registrar ocorrências, reunir evidências, acompanhar compromissos e perceber problemas recorrentes. Não substitui autoridades, administradora, síndico, advogado ou serviços de emergência.

## Comece por aqui

| Quero... | Caminho |
|---|---|
| Usar a aplicação | [Abrir o LASTRO](https://lastro.feraimentor.workers.dev) |
| Aprender do zero | [Manual do morador](docs/MANUAL_DO_MORADOR.md) |
| Administrar a comunidade | [Manual da administração](docs/MANUAL_DA_ADMINISTRACAO.md) |
| Resolver uma dúvida | [Base de conhecimento](docs/BASE_DE_CONHECIMENTO.md) |
| Entender o produto | [Documentação oficial](docs/DOCUMENTACAO_OFICIAL.md) |
| Ver privacidade e termos | [Documentos jurídicos](https://lastro.feraimentor.workers.dev/legal) |
| Reportar falha de segurança | [Política de segurança](SECURITY.md) |

## Em linguagem simples

O LASTRO diferencia duas coisas importantes:

- **Relato:** registro individual feito por uma pessoa, com descrição, data, local e evidências.
- **Problema coletivo:** agrupamento de relatos relacionados, usado para acompanhar o que afeta a comunidade.

Essa separação evita que várias pessoas sejam contadas como uma só ou que um problema recorrente pareça isolado. “Acompanhar” também é diferente de declarar que você foi diretamente afetado.

O sistema preserva dois pontos de vista: o estado informado pelo morador e o estado operacional comunicado por representação oficial. Uma divergência não é apagada; permanece como informação útil.

## Como usar em quatro etapas

1. Entre com sua conta Google.
2. Leia e aceite separadamente as três políticas vigentes.
3. Preencha o perfil e informe bloco e unidade.
4. Aguarde a verificação manual do vínculo.

Depois da aprovação, a navegação oferece:

- **Início:** resumo do que merece atenção;
- **Problemas:** pesquisa e consulta de problemas coletivos;
- **Registrar:** criação de um novo relato;
- **Meus relatos:** histórico do que você registrou;
- **Indicadores:** métricas com proteção contra exposição de grupos pequenos;
- **Notificações:** atualizações importantes;
- **Perfil:** dados, privacidade e preferências.

O passo a passo completo, inclusive para celular, está no [Manual do morador](docs/MANUAL_DO_MORADOR.md).

## Princípios do produto

- Não é rede social: não há curtidas, ranking, feed ou disputa de popularidade.
- A linguagem automática é neutra e não certifica verdade, culpa ou irregularidade.
- Alterações relevantes geram histórico; o original não é sobrescrito silenciosamente.
- Evidências ficam em armazenamento privado e usam links temporários.
- E-mail, WhatsApp, unidade e identidade protegida não aparecem para moradores comuns.
- Poder administrativo vem do RBAC atual no banco e pode ser revogado imediatamente.
- Importações históricas passam por staging e curadoria; ZIP bruto do WhatsApp não é aceito.
- Direitos de privacidade e pedidos de revisão têm fluxos próprios e auditáveis.

## Estado atual

A instância principal está publicada no Cloudflare Workers e usa Supabase para autenticação, banco de dados e armazenamento. O login Google, dashboard, diretório administrativo de usuários e cron de compromissos foram validados no ambiente hospedado.

O projeto mantém gate formal de liberação. A aplicação não deve ser declarada **READY FOR PRODUCTION** enquanto os itens V1 ainda bloqueados não forem aceitos. Permanecem externos, entre outros, o envio transacional por domínio/remetente verificado, o Preview isolado e alguns ensaios hospedados completos. Consulte o [ledger de implementação](docs/IMPLEMENTATION_STATUS.md).

## Documentação oficial

| Documento | Conteúdo |
|---|---|
| [Documentação oficial](docs/DOCUMENTACAO_OFICIAL.md) | missão, conceitos, jornadas, governança e glossário |
| [Manual do morador](docs/MANUAL_DO_MORADOR.md) | cadastro, registro, acompanhamento e privacidade |
| [Manual da administração](docs/MANUAL_DA_ADMINISTRACAO.md) | usuários, RBAC, moderação, auditoria e segurança |
| [Base de conhecimento](docs/BASE_DE_CONHECIMENTO.md) | perguntas frequentes e solução de problemas |
| [Especificação do produto](docs/PRODUCT_SPEC.md) | escopo e regras fundamentais da V1 |
| [Arquitetura](docs/ARCHITECTURE.md) | componentes, confiança e integrações |
| [Modelo de dados](docs/DATA_MODEL.md) | entidades e separações obrigatórias |
| [RLS e segurança](docs/RLS_SECURITY_MODEL.md) | autorização, personas e testes |
| [Aceite jurídico](docs/LEGAL_ACCEPTANCE_MODEL.md) | versões, hashes, aceite e reaceite |
| [Moderação](docs/MODERATION_MODEL.md) | sinalizações, decisões e revisão |
| [Importação histórica](docs/HISTORICAL_IMPORT.md) | CSV/XLSX, staging e privacidade |
| [Deploy e recuperação](docs/DEPLOYMENT_AND_RECOVERY.md) | ambientes, backup, restore e incidentes |
| [Plano de testes](docs/TEST_PLAN.md) | camadas e gates de qualidade |
| [Status de implementação](docs/IMPLEMENTATION_STATUS.md) | fonte de verdade sobre prontidão |

Os textos jurídicos canônicos ficam em [`legal/`](legal/) e os downloads em [`public/legal/`](public/legal/). Em caso de diferença entre resumo e documento jurídico integral vigente, prevalece o documento integral.

## Arquitetura resumida

```text
Pessoa no navegador
        │
        ▼
Next.js 16 no Cloudflare Workers
        │
        ├── Supabase Auth ── login Google
        ├── PostgreSQL ───── dados, RLS, auditoria e histórico
        ├── Storage privado  evidências e anexos
        └── Resend ───────── e-mail após domínio verificado
```

O servidor decide a próxima etapa do onboarding e revalida a autorização em cada operação sensível. Interface escondida nunca é tratada como controle de acesso.

## Tecnologias

- Next.js 16.3, React 19, TypeScript strict e Tailwind CSS 4;
- Supabase Auth, PostgreSQL, RLS e Storage;
- OpenNext e Cloudflare Workers;
- Zod, React Hook Form, Vitest, pgTAP, Playwright e axe;
- Resend atrás de uma interface de provedor de e-mail.

Node.js 20.9 ou superior é obrigatório. O projeto fixa Node 22 em `.nvmrc` e pnpm 11.16.0 no `package.json`.

## Estrutura do repositório

```text
LASTRO/
├── .github/                 CI, templates e responsáveis
├── docs/                    documentação técnica e operacional
├── legal/                   fontes jurídicas canônicas versionadas
├── public/legal/            documentos jurídicos para download
├── public/templates/        modelos CSV/XLSX sem dados reais
├── scripts/                 validações, backup e recuperação
├── src/app/                 páginas, ações e rotas
├── src/components/          componentes da interface
├── src/lib/                 domínio, Supabase, e-mail e segurança
├── supabase/migrations/     schema, funções, RLS e Storage
├── supabase/tests/          testes de banco e autorização
└── tests/                   testes unitários e E2E
```

## Desenvolvimento local

### Pré-requisitos

- Node.js 22;
- pnpm 11.16.0;
- Docker Desktop para o Supabase local;
- conta/projeto Supabase apenas para integrações hospedadas.

### Instalação

```bash
git clone https://github.com/feraimentor/LASTRO.git
cd LASTRO
pnpm install --frozen-lockfile
```

Copie `.env.example` para `.env.local` e use somente credenciais de desenvolvimento. Nunca aponte o ambiente local para produção.

```bash
pnpm exec supabase start
pnpm exec supabase db reset
pnpm dev
```

Abra `http://localhost:3000`. No Supabase local ou hospedado, habilite Google OAuth e permita `/auth/callback` no ambiente correspondente.

### Variáveis de ambiente

| Variável | Exposição | Finalidade |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | pública | URL do projeto Supabase |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | pública | chave publicável do cliente |
| `SUPABASE_SECRET_KEY` | segredo | operações exclusivas do servidor |
| `MASTER_BOOTSTRAP_EMAIL` | segredo operacional | associação idempotente do primeiro Master |
| `APP_URL` | configuração | origem HTTPS do ambiente |
| `EMAIL_PROVIDER` | configuração | `logger` em desenvolvimento ou `resend` em produção |
| `RESEND_API_KEY` | segredo | autenticação do provedor de e-mail |
| `EMAIL_FROM` | configuração | remetente verificado |
| `CRON_SECRET` | segredo | proteção dos jobs internos |

Nunca coloque secrets em `wrangler.jsonc`, commits, issues, prints ou logs. No Cloudflare, grave-os com `wrangler secret put`.

## Comandos

| Comando | Finalidade |
|---|---|
| `pnpm dev` | servidor local |
| `pnpm lint` | análise estática |
| `pnpm typecheck` | TypeScript sem emissão |
| `pnpm test` | testes unitários |
| `pnpm test:db` | testes pgTAP/RLS |
| `pnpm test:e2e` | testes Playwright |
| `pnpm legal:generate` | regenera hashes, seed e DOCX jurídicos |
| `pnpm legal:verify` | verifica sincronismo jurídico |
| `pnpm storage:inventory` | inventário autenticado dos buckets |
| `pnpm release:env` | valida variáveis mínimas de release |
| `pnpm build` | build Next.js |
| `pnpm build:cloudflare` | gera Worker pelo OpenNext |
| `pnpm deploy:cloudflare` | gera e publica no Cloudflare |
| `pnpm check` | lint, tipos, unitários e build |

## Segurança e privacidade

Rotas comunitárias exigem autenticação, aceites vigentes, perfil completo, vínculo aprovado e acesso ativo. Rotas administrativas verificam permissões atuais no banco. Views comunitárias usam `security_invoker`, tabelas expostas usam RLS e anexos ficam no bucket privado `evidence`.

Não abra issue pública com dado pessoal, relato real, token, URL assinada ou vulnerabilidade explorável. Siga [SECURITY.md](SECURITY.md).

## Contribuições

O código é público para transparência e auditoria, mas não é software livre nem open source. Antes de contribuir, leia [CONTRIBUTING.md](CONTRIBUTING.md). Issue ou pull request não concede autorização para reutilizar o software nem transfere direitos automaticamente.

## Direitos autorais e licença

Copyright © 2026 Bruno Moreira. Todos os direitos reservados.

Este repositório é **source-available com licença proprietária**. A visualização pública não concede permissão para copiar, usar, modificar, publicar, distribuir, sublicenciar, comercializar ou criar obra derivada, salvo autorização prévia e escrita do titular. O GitHub pode permitir visualização e fork dentro da plataforma conforme seus Termos de Serviço. Consulte [LICENSE.md](LICENSE.md) e [NOTICE.md](NOTICE.md).
