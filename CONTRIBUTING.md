# Contribuindo com o LASTRO

Este repositório é público para transparência, mas o software tem licença proprietária e não é open source.

Antes de implementar uma mudança extensa, abra uma issue sem dados pessoais e aguarde confirmação do mantenedor. Relatórios de segurança seguem [SECURITY.md](SECURITY.md), nunca uma issue pública.

## Regras

- preserve a especificação V1 e o ledger;
- não enfraqueça RLS, RBAC, auditoria, histórico ou privacidade;
- não use PII real em testes, seeds ou exemplos;
- mantenha migrations, testes e documentação sincronizados;
- use TypeScript strict e a arquitetura Next.js + Supabase existente;
- valide `pnpm legal:verify`, lint, tipos, testes e build;
- explique risco, teste e impacto no pull request.

O envio de contribuição não autoriza o uso do LASTRO nem garante incorporação. O titular poderá exigir acordo escrito e confirmação de autoria/licenciamento antes de aceitar código externo.

Use commits no formato `tipo: descrição objetiva`, com tipos como `feat`, `fix`, `docs`, `test`, `refactor`, `chore` e `security`.
