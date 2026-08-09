# LASTRO — regras de engenharia

- A especificação congelada V1 e docs/IMPLEMENTATION_STATUS.md são o contrato de entrega. Nenhum requisito pode desaparecer.
- Implementar na ordem M0 a M7. Não avançar mascarando falha crítica de segurança, RLS, migration ou gate anterior.
- Arquitetura: Next.js full-stack + TypeScript strict + Supabase Auth/PostgreSQL/Storage. Não criar backend Node separado.
- Google OAuth autentica; autorização comunitária exige aceite jurídico vigente, perfil, vínculo e verificação. A próxima etapa é decidida no servidor.
- Autorização administrativa vem do RBAC atual no banco, por UUID. Não usar e-mail espalhado, is_admin, user_metadata nem JWT antigo como fonte final.
- Todas as tabelas expostas usam RLS de menor privilégio. UI escondida não é controle de acesso. Views comunitárias usam security_invoker e não expõem PII/identidade protegida.
- Reports individuais e issues coletivas são entidades diferentes. Acompanhar e declarar-se afetado são relações diferentes.
- Status do morador e status operacional oficial são independentes. Divergência é informação válida.
- Estado atual pode ser mutável para UX; toda mudança relevante gera timeline append-only. Auditoria administrativa é separada e não editável pela aplicação.
- Não fazer overwrite silencioso de relatos, evidências, prazos, versões jurídicas, eventos ou auditoria. Preferir complemento, versão, histórico e soft delete.
- Evidências ficam em bucket privado, sem URL pública permanente e com autorização equivalente ao conteúdo relacionado.
- Linguagem automática deve ser neutra; a plataforma não certifica verdade, culpa ou irregularidade.
- Nunca importar automaticamente ZIP bruto do WhatsApp. Importação V1 é manual/CSV/XLSX, passa por staging e preserva proveniência e privacidade.
- Não usar PII real em seeds ou fixtures. O Master inicial só é associado após login Google real, via MASTER_BOOTSTRAP_EMAIL.
- Datas no PostgreSQL em UTC; interface pt-BR e America/Sao_Paulo. UX mobile-first e WCAG 2.2 AA.
- Fixar dependências e lockfile. Manter código, migrations, testes, seeds e documentação sincronizados.
- Só usar IMPLEMENTED quando o fluxo estiver integrado; TESTED quando teste válido passar; ACCEPTED quando o gate do marco passar.
- Nunca escrever READY FOR PRODUCTION sem todos os gates, RLS/E2E, e-mail, ambientes, backup e restore validados.


<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
