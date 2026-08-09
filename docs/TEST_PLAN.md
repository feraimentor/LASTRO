# Plano de testes e gates

## Camadas

- Unit/Vitest: importação strict, upload, e-mail e sanitização de observabilidade.
- PostgreSQL/pgTAP: migrations do zero, constraints, transações, RLS, personas, Storage metadata, jurídico, RBAC, governança, KPIs, importação e operações.
- E2E/Playwright: rotas públicas em desktop e mobile; axe WCAG 2.2 AA nas páginas públicas.
- Hosted E2E: OAuth Google, Storage real, e-mail Resend, cron, revogação administrativa e jornadas autenticadas.

## Jornadas bloqueadoras

Morador: login Google, três aceites, perfil, vínculo, aprovação, criação de relato, evidência privada, timeline, retorno, compromisso e estados. Admin: delegação granular sem autoelevação, moderação reversível, revogação imediata e auditoria. Case: convite com hash/expiração/uso único e acesso somente ao caso. Histórico: manual/CSV/XLSX, staging, correção, aprovação, publicação/associação, proveniência e separação de KPI. Jurídico: três hashes, imutabilidade e reaceite material.

## Resultado local de 2026-08-09

- TypeScript strict: passou.
- Vitest: 8/8.
- pgTAP em banco PostgreSQL recriado do zero: 110/110.
- Restore drill local: passou; três políticas vigentes, zero tabela pública sem RLS e zero view insegura.
- XLSX histórico: inspecionado, sem erros de fórmula e renderizado nas três abas.

Ainda são gates externos: Supabase completo/Storage via Docker ou projeto hospedado, OAuth real, Resend real, E2E autenticado, mobile completo em jornadas privadas, axe de todas as páginas privadas, staging/produção separados e restore de staging com objetos reais.

Qualquer falha RLS, migration, jurídico, identidade protegida, busca, case access, Storage ou importação bloqueia release. Não usar “READY FOR PRODUCTION” enquanto um gate externo obrigatório permanecer aberto.
