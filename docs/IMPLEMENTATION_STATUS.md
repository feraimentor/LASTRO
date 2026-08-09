# Status de implementação — LASTRO V1

Atualizado em 2026-08-09. Greenfield. Este ledger não pode ter linhas removidas para ocultar pendências.

Estados permitidos: NOT STARTED, IN PROGRESS, BLOCKED, IMPLEMENTED, TESTED, ACCEPTED, DEFERRED TO V1.1, BACKLOG.

| ID | Requisito | Marco | Status | Teste | Observação |
|---|---|---:|---|---|---|
| FOUNDATION-001 | Scaffold Next.js App Router, TypeScript strict e Tailwind | M0 | TESTED | build/typecheck | Next 16.3; build de 39 páginas e typecheck verdes |
| FOUNDATION-002 | Supabase local, CLI e migrations versionadas | M0 | TESTED | migration smoke/pgTAP | Dez migrations e seeds aplicados do zero em PostgreSQL 16 isolado e no projeto hospedado `heideeuesoyiryooadcb`; 112 testes pgTAP verdes |
| FOUNDATION-003 | Env example, lockfile e dependências fixadas | M0 | TESTED | install frozen | Instalação congelada concluída com pnpm 11.16.0 |
| FOUNDATION-004 | Tokens visuais LASTRO e UI mobile-first | M0 | TESTED | visual/a11y | Landing e jurídico inspecionados no navegador em desktop e 390px |
| FOUNDATION-005 | CI com lint, typecheck, unit, build, migration e E2E | M0 | IMPLEMENTED | workflow | Jobs separados de Supabase/migrations, qualidade/build e Playwright/axe implementados; execução remota depende do GitHub |
| DOC-001 | README e documentação técnica obrigatória | M0 | IMPLEMENTED | docs inventory | README e nove documentos técnicos versionados |
| DOC-002 | Ledger integral e sincronizado | M0 | IMPLEMENTED | manual | Este arquivo |
| AUTH-001 | Login exclusivo Google via Supabase Auth | M1 | IMPLEMENTED | auth integration | Adapter/callback PKCE implementados; Google real depende de credenciais |
| AUTH-002 | Autenticação separada de autorização condominial | M1 | IMPLEMENTED | RLS/personas | Login, aceite, perfil, vínculo e acesso são estados distintos |
| AUTH-003 | Portão jurídico com três aceites separados | M1 | IMPLEMENTED | legal integration | RPC atômica exige conjunto vigente completo e audita |
| AUTH-004 | Onboarding dirigido pelo servidor | M1 | IMPLEMENTED | route integration | Roteamento reavalia estado server-side |
| AUTH-005 | Estados de acesso explícitos | M1 | TESTED | pgTAP/personas | Enums e transições de residente, pendente, oficial, case participant, encerrado e suspenso validados |
| LEGAL-001 | Políticas públicas em rotas estáveis | M1 | TESTED | route tests | Três rotas e downloads confirmados no navegador |
| LEGAL-002 | Versões publicadas imutáveis, hash canônico e download | M1 | TESTED | DB/unit | Hash/seed verificados e trigger de imutabilidade passou no pgTAP |
| LEGAL-003 | Aceite server-side com hash e auditoria | M1 | IMPLEMENTED | integration | RPC security-definer transacional implementada |
| LEGAL-004 | Reaceite material bloqueia comunidade | M1 | IMPLEMENTED | integration/RLS | Helper de acesso exige hash da versão current |
| LEGAL-005 | Gestão jurídica administrativa com reauth | M4 | TESTED | pgTAP/integration | Rascunho, hash, reaceite e publicação imutável com sessão recente integrados; E2E OAuth hospedado pendente |
| LEGAL-006 | Fonte canônica e geração determinística de DOCX | M1 | IMPLEMENTED | hash/render | Três DOCX sincronizados e estruturalmente válidos; render paginado bloqueado sem LibreOffice |
| PROFILE-001 | Perfil completo e preferências | M1 | IMPLEMENTED | integration | Onboarding de perfil e área pessoal implementados |
| PROFILE-002 | PII separada e não exposta | M1 | TESTED | pgTAP/RLS | Schema private e projeção comunitária sem UUID/PII validados com duas personas |
| UNIT-001 | Blocos 1–14 e catálogo administrável de unidades | M1 | IMPLEMENTED | seed/integration | Seed 1–14, catálogo e tela administrativa |
| VERIFY-001 | Verificação manual com estados e trilha | M1 | TESTED | pgTAP/integration | RPC atômica de solicitação/decisão, cinco estados congelados e fila administrativa |
| VERIFY-002 | Encerramento de vínculo preserva autoria e acesso mínimo | M1 | TESTED | pgTAP/RLS | RPC encerra vínculo, muda acesso para link_ended e preserva os reports/autoria |
| MASTER-001 | Bootstrap único do Master por ambiente e UUID | M1 | IMPLEMENTED | integration/audit | Bootstrap centralizado, idempotente e auditado |
| MASTER-002 | Poderes Master completos via permissões | M4 | TESTED | pgTAP/integration | Vínculos, suspensão, RBAC, jurídico, moderação, importação, configurações, incidentes e recovery integrados |
| MASTER-003 | Guard técnico do último Master | M1 | TESTED | pgTAP | Trigger impede revogação do último Master ativo |
| RBAC-001 | Roles, permissions, mappings, user roles e overrides | M1 | IMPLEMENTED | DB/RLS | Schema, seed e helper de decisão atual implementados |
| RBAC-002 | Revogação administrativa imediata consultando banco | M1 | TESTED | pgTAP/integration | Guardas e mutações consultam RBAC atual; concessão/revogação UI e deny override integrados |
| RBAC-003 | Autoelevação e alteração de nível superior proibidas | M1 | IMPLEMENTED | DB/integration | Sem grants de mutação ao cliente; operações privilegiadas isoladas |
| RBAC-004 | Revogação preserva usuário e histórico | M1 | IMPLEMENTED | DB | Modelo usa revoked_at sem deleção de usuário |
| RBAC-005 | Reautenticação em operações críticas | M1 | TESTED | pgTAP/integration | Sessão Supabase criada há no máximo 15 min exigida em RBAC, suspensão e publicação jurídica; UI reabre Google |
| TAX-001 | Seis tipos de registro configuráveis | M2 | IMPLEMENTED | seed | Seed completo |
| TAX-002 | Categorias, subcategorias, aliases e sugestões configuráveis | M2 | IMPLEMENTED | seed/integration | Taxonomia V1 completa e tela de consulta admin |
| TAX-003 | Outros exige sugestão sem bloquear publicação | M2 | IMPLEMENTED | form/integration | Validado na RPC transacional |
| TAX-004 | Locais múltiplos e abrangência configurável | M2 | TESTED | DB/integration | Seleção múltipla persiste atomicamente em report_locations/issue_locations; sete abrangências V1 |
| REPORT-001 | Busca simples antes de criar issue | M2 | IMPLEMENTED | search integration | Busca por título e chamada obrigatória no fluxo |
| REPORT-002 | Protocolos nativos e históricos únicos/transacionais | M2 | IMPLEMENTED | DB concurrency | Sequences e RPC transacional; concorrência não executada |
| REPORT-003 | Relato original sem overwrite silencioso | M2 | IMPLEMENTED | DB/integration | Tabela original + versions; cliente não recebe UPDATE |
| REPORT-004 | Complementos append-only | M2 | IMPLEMENTED | DB/integration | Trigger append-only e RLS implementadas |
| REPORT-005 | occurred_at separado de recorded_at server-side | M2 | IMPLEMENTED | DB | Campos e gravação server-side separados |
| REPORT-006 | Declaração de boa-fé registrada | M2 | IMPLEMENTED | integration | Checkbox obrigatório e timestamp/evento na RPC |
| REPORT-007 | Urgência, risco, sensibilidade, identidade e visibilidade | M2 | IMPLEMENTED | form/RLS | Formulário, enums e projeção segura |
| ISSUE-001 | Issue coletiva separada de reports | M2 | IMPLEMENTED | integration | Modelo, métricas e página coletiva |
| ISSUE-002 | Status coletivo derivado com histórico-only seguro | M2 | TESTED | pgTAP/DB | Recalcula por origem, status configurado e compromissos; mudança gera timeline append-only |
| ISSUE-003 | Merge, split, reassignment e undo com justificativa/histórico | M4 | TESTED | pgTAP/admin | Merge, split e undo preservam reports e história; UI administrativa integrada |
| ISSUE-004 | Afetados, unidades/blocos e seguidores separados | M2 | TESTED | pgTAP/RLS | RPCs independentes, snapshot de unidade validada, UUIDs não enumeráveis e UI integrada |
| STATUS-001 | Status de morador configurado por tipo | M2 | IMPLEMENTED | seed/integration | Definições completas em seed |
| STATUS-002 | Status operacional oficial independente | M3 | TESTED | pgTAP/RLS | Estado oficial append-only e separado do estado do morador |
| RESP-001 | Retorno externo atribuído e rotulado | M3 | TESTED | pgTAP/integration | Retorno externo exige autoria/atribuição e rótulo neutro |
| RESP-002 | Resposta oficial só por representação válida | M3 | TESTED | pgTAP/RLS | Representação vigente é verificada no banco |
| RESP-003 | Partes citadas e acesso restrito a caso por convite | M3 | TESTED | pgTAP/RLS | Convite com hash, expiração e uso único; grant isolado por caso |
| COMMIT-001 | Compromissos e prazos com estado atual | M3 | TESTED | pgTAP/integration | Criação integrada a respostas e timeline |
| COMMIT-002 | Histórico de reprogramação e job overdue idempotente | M3 | TESTED | pgTAP/job | Histórico append-only e job idempotente validados |
| TIMELINE-001 | Eventos comunitários append-only | M2 | IMPLEMENTED | DB/integration | Tabela, trigger, RLS e UI de timeline |
| AUDIT-001 | Auditoria administrativa separada e imutável pela aplicação | M1 | IMPLEMENTED | DB/RLS | Tabela append-only e tela permissionada |
| STORAGE-001 | Bucket privado e metadados de anexos com SHA-256 | M3 | TESTED | pgTAP/unit | Reserva, upload/finalização, SHA-256, bucket privado e UI integrados; objeto real hospedado ainda requer gate externo |
| STORAGE-002 | Validação de MIME/extensão/tamanho e preview seguro | M3 | TESTED | unit/integration | MIME/extensão/tamanho e signed download curto integrados |
| STORAGE-003 | Path sem PII, sem overwrite e download autorizado | M3 | TESTED | pgTAP/RLS | Path opaco, upload único e acesso equivalente ao relato validados |
| MOD-001 | Flags, ações motivadas e fila de moderação | M4 | TESTED | pgTAP/admin | Flags, fila, decisões motivadas e UI integradas |
| MOD-002 | Restrição/ocultação/restauração preservam histórico | M4 | TESTED | pgTAP/integration | Ações e reversão atômica preservam conteúdo/auditoria |
| MOD-003 | Pedido de revisão de moderação/suspensão | M4 | TESTED | pgTAP/integration | Solicitação pelo afetado e decisão separada integradas |
| PRIVACY-001 | Solicitações LGPD na área do perfil | M4 | TESTED | pgTAP/integration | Tipos V1 e área pessoal integrados |
| PRIVACY-002 | Decisão administrativa sem deleção automática irrestrita | M4 | TESTED | pgTAP/audit | Decisão com reauth e auditoria; nenhuma deleção automática |
| SEARCH-001 | Full-text PostgreSQL + aliases e índices | M2 | TESTED | pgTAP/integration | websearch_to_tsquery em português, ranking, GIN e UI integrados |
| SEARCH-002 | Busca obedece visibilidade sem snippets/contagens vazados | M2 | TESTED | pgTAP/RLS | Projeção security_invoker omite relato restrito para outra persona |
| KPI-001 | Diferenciar reports, issues, pessoas, unidades e blocos | M5 | IMPLEMENTED | reference queries | View e cards usam contagens semanticamente distintas |
| KPI-002 | Medianas de resposta e resolução | M5 | TESTED | reference queries | Medianas com amostra mínima e filtro de origem implementadas |
| KPI-003 | Buckets de aging definidos | M5 | IMPLEMENTED | unit/query | View report_aging e UI implementadas |
| KPI-004 | Primeiro retorno conhecido separado de resposta oficial | M5 | TESTED | query | CTEs e cards distintos |
| KPI-005 | Linguagem de ausência de retorno neutra | M5 | TESTED | UI test | Texto neutro presente e confirmado no build |
| KPI-006 | Compromissos no prazo/atrasados/vigentes/vencidos | M5 | TESTED | query | Quatro métricas filtradas por origem e cards integrados |
| KPI-007 | Recorrência separada de persistência | M5 | IMPLEMENTED | query | Campos distintos no domínio |
| KPI-008 | Status divergente mensurado | M5 | TESTED | query | Estado oficial terminal × morador não terminal mensurado |
| KPI-009 | Tipos de registros não misturados | M5 | IMPLEMENTED | UI/query | Tipos persistidos/configurados de forma distinta |
| KPI-010 | Drill-down de todo KPI relevante | M5 | IMPLEMENTED | integration | KPIs clicáveis usam RPC filtrada; validação E2E privada permanece externa |
| KPI-011 | Limiar estatístico mínimo 3 | M5 | TESTED | pgTAP/security | Contagens e medianas abaixo do limiar são suprimidas; configuração não aceita valor menor que 3 |
| KPI-012 | Origem nativa/histórica separada | M5 | TESTED | pgTAP/query | Filtros nativos/históricos/todos e default nativo validados |
| IMPORT-001 | Importação manual, CSV e XLSX | M6 | TESTED | unit/pgTAP | Parser strict, upload administrativo e criação manual integrados |
| IMPORT-002 | Staging obrigatório e estados de revisão | M6 | TESTED | pgTAP | Nenhum item é publicado antes de aprovação explícita |
| IMPORT-003 | Proveniência completa | M6 | TESTED | pgTAP | Fonte, referência, data original/importação, notas e bruto restrito preservados |
| IMPORT-004 | Pseudonimização e minimização histórica | M6 | TESTED | pgTAP/privacy | Chave vira SHA-256 e pseudônimo; plaintext é descartado |
| IMPORT-005 | Publicação curada/merge sem publicação automática | M6 | TESTED | pgTAP | Nova issue e associação existente, protocolo HIST e timeline validados |
| IMPORT-006 | Desfecho desconhecido não tratado como ativo | M6 | TESTED | pgTAP/query | `outcome_unknown` e `historical_only` validados |
| IMPORT-007 | Templates CSV/XLSX e documentação sem dados reais | M6 | TESTED | artifact QA | XLSX inspecionado/renderizado em 3 abas; CSV equivalente |
| NOTIFY-001 | Central interna e preferências essenciais/opcionais | M5 | TESTED | pgTAP/integration | Central, leitura, preferências e eventos essenciais independentes integrados |
| NOTIFY-002 | EmailProvider isolado, fake dev e Resend produção | M5 | TESTED | provider tests | Fake sem PII em log testado; produção depende de credencial/domínio |
| SEC-001 | RLS em toda tabela exposta e matriz de personas | M1 | TESTED | pgTAP/hosted advisor | 112 testes verdes; public sem tabela sem RLS, private user data com RLS deny-by-default, views invoker, sem função pública definer; advisor hospedado sem alerta de segurança |
| SEC-002 | Projeções comunitárias sem identidade protegida/PII | M1 | TESTED | pgTAP | Views security_invoker; projeção sem UUID de autor/unidade e rótulo neutro validado |
| SEC-003 | Rate limits configuráveis e constraints anti-duplo clique | M2 | TESTED | pgTAP/integration | Limites server-side por família de ação leem `app_settings`; alteração Master auditada e aplicação imediata validadas |
| SEC-004 | Headers, CSP, cookies, CSRF, noindex e validação server-side | M7 | TESTED | hosted security smoke | Vercel confirmou CSP, HSTS, frame-ancestors none, nosniff, Permissions-Policy e noindex; cron sem bearer retorna 401 |
| SEC-005 | Soft delete/retenção e hard delete excepcional auditado | M4 | IMPLEMENTED | DB/integration | Entidades usam archive/hidden/revoked/ended; hard delete não é concedido à aplicação |
| OPS-001 | Logs estruturados sem tokens/PII e saúde administrativa | M7 | TESTED | unit/pgTAP | Correlation ID, sanitização, job/failure tables e painel Master validados |
| OPS-002 | Incidentes de segurança admin-only e procedimento | M7 | TESTED | pgTAP/RLS/docs | Workflow, auditoria, isolamento de moradores e procedimento documentados |
| OPS-003 | Backup DB/Storage e restauração documentada | M7 | TESTED | restore drill | Scripts e docs; drill local real passou. Restore de staging com Storage real permanece bloqueio externo |
| OPS-004 | Ambientes development/preview/production separados | M7 | BLOCKED | deployment | Supabase de produção ativo em São Paulo; secret server-side sensível e URLs de Auth configurados; deployment Vercel protegido com smoke público verde. Master, OAuth Google, Resend/domínio, Supabase Preview, novo deploy e E2E autenticado ainda pendentes |
| TEST-001 | Personas e suíte unit/integration | M0–M7 | TESTED | Vitest/pgTAP | 10 testes unitários e 112 testes de banco/personas verdes |
| TEST-002 | Suíte RLS bloqueadora completa | M1–M7 | TESTED | pgTAP/integration | M0–M7 com matriz de anon, pendente, moradores, oficial, case, Master e service_role |
| TEST-003 | E2E morador completo | M3 | BLOCKED | Playwright hosted | Fluxos/RPC/RLS estão testados; browser exige Google OAuth e projeto Supabase real configurados |
| TEST-004 | E2E admin e revogação | M4 | BLOCKED | Playwright hosted | Fluxos/RPC/RLS estão testados; delegação/revogação no browser exige contas Google reais de teste |
| TEST-005 | E2E histórico | M6 | TESTED | pgTAP/integration | Jornada integral de lote a publicação/associação e KPI passou no banco; browser autenticado externo pendente |
| TEST-006 | Testes jurídicos de aceite/hash/imutabilidade/reaceite | M1 | TESTED | pgTAP/DB | Três aceites vigentes, imutabilidade, sessão recente e hashes canônicos validados |
| TEST-007 | Mobile e WCAG 2.2 AA com axe | M7 | IMPLEMENTED | Playwright/axe | Desktop/mobile e axe públicos no CI; jornadas privadas hospedadas permanecem BLOCKED |
| V1.1-001 | Sugestão sofisticada/IA de duplicidade | V1.1 | DEFERRED TO V1.1 | n/a | Não substitui busca textual V1 |
| V1.1-002 | Comparativos avançados, PDF executivo e exports avançados | V1.1 | DEFERRED TO V1.1 | n/a | — |
| V1.1-003 | Digests/presets/revisões avançadas e segunda revisão | V1.1 | DEFERRED TO V1.1 | n/a | — |
| V1.1-004 | Materialized views, redação de imagens e PWA/push avançado | V1.1 | DEFERRED TO V1.1 | n/a | — |
| BACKLOG-001 | IA de categoria/resumo/relatórios e embeddings | Backlog | BACKLOG | n/a | — |
| BACKLOG-002 | Parser automático de WhatsApp ZIP e WhatsApp API | Backlog | BACKLOG | n/a | Proibido na V1 |
| BACKLOG-003 | Apps nativos, portal público e votações | Backlog | BACKLOG | n/a | — |

## Bloqueios externos conhecidos

- Docker não está instalado neste ambiente; o stack binário local do Storage não foi executado. As dez migrations e seeds foram reproduzidos em PostgreSQL 16 isolado via WSL (112 testes pgTAP) e aplicados com sucesso no Supabase hospedado em `sa-east-1`.
- LibreOffice/soffice não está instalado; DOCX passaram por hash e inspeção estrutural, mas não por renderização paginada visual.
- O projeto Supabase `LASTRO` (`heideeuesoyiryooadcb`) está saudável, com migrations/seeds sincronizados, zero FK descoberta sem índice de cobertura e advisors sem WARN/ERROR; avisos INFO de RLS sem política são deny-by-default deliberado e índices novos aparecem como não usados enquanto o banco está vazio.
- Projeto Vercel `lastro` existe na conta Hobby e a CLI 58.9.0 está autenticada/vinculada. O primeiro deployment protegido está READY em `https://lastro-five.vercel.app`; rotas públicas retornam 200, headers de segurança estão presentes e o cron rejeita chamada anônima com 401. Variáveis públicas, URL final, limites, timezone, secret moderno do Supabase e um `CRON_SECRET` criptograficamente aleatório estão configurados; a chave transitória exposta durante a configuração foi revogada antes de uso. Como variáveis foram adicionadas após esse build, elas entrarão no próximo deployment controlado.
- No Supabase, Site URL e callback PKCE apontam para `https://lastro-five.vercel.app`. Permanecem externos: aceite da política de dados Google para criar o OAuth Client, autorização literal do e-mail do Master, compra e verificação de domínio para Resend, confirmação do segundo Supabase gratuito para Preview, novo deploy com o conjunto completo, E2E autenticado e restore com Storage real. O deployment atual permanece protegido e com `noindex`, sem alegação de lançamento produtivo.
- READY FOR PRODUCTION não será usado até todos os requisitos V1 estarem ACCEPTED.
