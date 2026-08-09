# Produto — LASTRO V1

## Missão

Registrar, documentar, agrupar e acompanhar problemas do Condomínio Alto Icaraí preservando cronologia, evidências, respostas, compromissos, recorrências, contraditório e avaliação do reclamante. O sistema mantém memória institucional independente do síndico ou administradora.

## Regras fundamentais

- LASTRO não é rede social: não há feed social, likes, reações, ranking ou thread livre.
- Report é relato individual; issue é problema coletivo. Métricas não confundem ambos.
- Afetado registra impacto real; follower apenas acompanha.
- Status do morador e status operacional oficial coexistem, inclusive em divergência.
- Retorno externo registrado pelo usuário nunca é exibido como resposta oficial.
- Estado atual convive com história append-only; nada relevante é sobrescrito silenciosamente.
- A plataforma registra alegações e evidências sem julgar verdade.
- Conteúdo comunitário é privado para pessoas com vínculo verificado.

## Escopo V1

A V1 inclui Google OAuth; portão jurídico; perfil, unidades e verificação; Master/RBAC; taxonomia; reports/issues; busca; afetados/followers; status; timeline; Storage privado; respostas e contraditório; compromissos; moderação e revisão; direitos LGPD; dashboards; notificações; contas oficiais; importação histórica manual/CSV/XLSX; RLS; rate limit; observabilidade; backup/restore; CI e documentação.

O escopo detalhado e os critérios verificáveis estão preservados linha a linha em IMPLEMENTATION_STATUS.md. Os textos jurídicos canônicos ficam em legal/ e não podem ser resumidos na versão aceita.

## Fora da V1

IA/embeddings, parser de ZIP WhatsApp, WhatsApp API, apps nativos, portal público de reclamações, votações e recursos sociais permanecem V1.1/backlog. O ZIP bruto nunca é importado automaticamente.

## Release

READY FOR PRODUCTION requer todos os requisitos V1 ACCEPTED, RLS e E2E verdes, migrations/seeds reproduzíveis, Storage privado, legal/reaceite, RBAC/auditoria, busca/identidade protegida/case access seguros, import/KPIs/email/mobile/a11y/hardening validados e restore testado.
