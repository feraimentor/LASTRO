# Modelo de RLS e segurança

## Princípio

RLS é bloqueador de release. Toda tabela public habilita RLS. Nenhuma policy concede acesso apenas por TO authenticated: também exige ownership, vínculo comunitário, representação, case grant ou permissão atual.

## Personas mínimas

Anon lê somente políticas públicas. Auth sem aceite lê dados próprios e políticas. Pendente não lê comunidade. Morador verificado lê projeções comunitárias autorizadas. Conta oficial age apenas dentro de representação válida. Case participant vê somente o caso. Moderador e admin recebem permissões explícitas. Master passa por RBAC e guards estruturais.

## Identidade protegida

Views/projeções comunitárias não retornam author_user_id, unit_id, apartamento, email ou WhatsApp quando a identidade é protegida. Busca e Storage reutilizam a mesma função de autorização do conteúdo.

## Funções auxiliares

Funções SECURITY DEFINER somente quando indispensáveis, no schema private, com search_path fixo, verificação de auth.uid, EXECUTE revogado de PUBLIC e grant mínimo. Permissões críticas consultam tabelas atuais para revogação imediata.

## Testes bloqueadores

A suíte cobre PII entre usuários, ownership, anexos, não verificados, contas oficiais, moderador sem PII, identidade protegida, busca, views, case grants, convites, revogação, Master e Storage.

Incidentes, falhas, jobs e drills são invisíveis a moradores. Somente `settings.manage` lê o painel de saúde; apenas `service_role` executa RPCs de telemetria, e metadados com chaves de segredo são rejeitados no banco.
