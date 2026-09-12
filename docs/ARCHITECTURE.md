# Arquitetura — LASTRO V1

## Visão geral

LASTRO é uma aplicação Next.js App Router full-stack. React Server Components realizam leitura inicial; Server Actions e Route Handlers validam entrada com Zod, confirmam identidade no servidor e executam operações transacionais no Supabase. Componentes cliente ficam restritos à interação real.

O Supabase fornece Google Auth, PostgreSQL e Storage privado. Cloudflare Workers hospeda o bundle Next.js gerado pelo OpenNext e aciona os endpoints cron protegidos; a regra de vencimento permanece idempotente e independente do scheduler.

## Limites de confiança

1. Google/Supabase prova a identidade autenticada.
2. Aceites jurídicos vigentes autorizam iniciar o perfil.
3. Perfil e solicitação de vínculo permitem aguardar verificação.
4. Vínculo aprovado e não encerrado libera comunidade.
5. Representação oficial libera somente ações oficiais do mandato.
6. RBAC atual do banco libera ações administrativas específicas.
7. Case grant libera somente o caso indicado.

Autorização crítica é reavaliada no PostgreSQL/servidor a cada operação. user_metadata e claims antigas não concedem privilégios.

## Domínios

- Identidade: profiles, private.user_private_data, blocks, units, links e verificação.
- Jurídico: documentos, versões imutáveis, aceites e reaceite.
- Governança: RBAC, representações, convites, auditoria, moderação e privacidade.
- Memória: issues coletivas, reports individuais, versões, complementos e timeline.
- Contraditório: retornos externos, respostas oficiais e manifestações de partes.
- Evidências: metadados relacionais + objetos privados sem overwrite.
- Operação: compromissos, prazos, notificações, importação, KPIs, jobs, falhas sanitizadas, incidentes e evidências de restore.

## Estado e história

Entidades de domínio mantêm estado atual para consulta. Triggers e serviços gravam eventos append-only para toda mudança relevante. Alterações excepcionais do texto original geram report_versions. Prazos reprogramados geram commitment_deadline_history. Auditoria administrativa é separada da timeline comunitária e evita copiar PII indiscriminadamente.

## Segurança de dados

- public é schema exposto e toda tabela nele usa RLS.
- private não é exposto; funções privilegiadas ficam nesse schema, com search_path fixo, execute revogado de PUBLIC e grants mínimos.
- Views comunitárias usam security_invoker e projetam rótulos de autoria, nunca UUID/PII de identidade protegida.
- Storage evidence é privado. A autorização consulta attachments e o report relacionado; conhecer o path não basta.
- Chave publishable pode ir ao navegador. Secret/service role é somente servidor e não substitui controles de domínio.

## Fluxo de publicação

Registrar cria report + protocolo + issue provisória ou vínculo a issue existente + evento, em transação. Complementos são append-only. A declaração de afetado e o follow são relacionamentos únicos separados. Status do morador nunca é substituído por status oficial.

## Integrações

EmailProvider possui adapter logger para desenvolvimento e Resend para produção. Storage, email, scheduler e observabilidade ficam atrás de interfaces. Isso permite preview sem enviar email e impede que o domínio dependa de fornecedor único.

Route Handlers de cron emitem JSON estruturado com correlation ID, rota, operação e código seguro. Tokens, PII e conteúdo integral são removidos. O banco guarda somente falhas operacionais sanitizadas e resultados de jobs; o painel Master consulta essas tabelas sob RLS.

## Decisões atuais verificadas

- Next.js 16 App Router exige Node 20.9+.
- Supabase SSR usa @supabase/ssr e PKCE; callback troca code por sessão.
- Em operações server-side, identidade é validada por chamada Auth ao servidor, nunca por objeto de sessão não verificado.
- RLS combina TO authenticated com predicado de autorização; UPDATE recebe USING e WITH CHECK e precisa de SELECT correspondente.
- Views Postgres 15+ usam security_invoker.
