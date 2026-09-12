# Manual da administração — LASTRO

Destina-se a Master, administradores, moderadores e pessoas com permissões específicas. Ver um item no menu não substitui autorização; servidor e banco revalidam cada operação.

## Painel

Entre com Google e abra **Administração** ou `/admin`. O menu oferece visão geral, usuários, verificações, moradores, unidades, moderação, categorias, problemas, importações, contas oficiais, administradores, jurídico, privacidade, auditoria, configurações e segurança.

Use a visão geral para priorizar verificações, sinalizações, importações e incidentes.

## Usuários e UUID

Abra **Administração → Usuários** (`/admin/usuarios`). Pesquise por nome, e-mail, bloco, unidade ou UUID. O resultado exibe UUID completo com **Copiar**, onboarding, acesso, vínculo, unidade, papéis, permissões e atalhos.

Use UUID em operações administrativas. Antes de agir, confira identidade, unidade e estado.

## Verificação e vínculo

Em **Verificações**, analise somente dados necessários. Antes de aprovar:

1. confirme pessoa e unidade;
2. não copie dados privados para campos públicos;
3. registre justificativa objetiva;
4. crie unidade ausente apenas quando autorizado;
5. revise a decisão.

Pedido de complemento e rejeição devem explicar o necessário sem excesso de PII. Encerrar vínculo preserva autoria e histórico.

## Suspensão e unidades

Suspensão exige motivo e autenticação recente. Não a use para divergência de opinião; aplique apenas às hipóteses de governança e segurança. Pedidos de revisão são eventos separados.

Em **Unidades**, mantenha catálogo, evite duplicidade e prefira arquivar a apagar. Verifique vínculos antes de alterar.

## Moderação e problemas

Sinalização não é prova. Leia o contexto autorizado, aplique ação proporcional e registre motivo neutro sem copiar conteúdo sensível. Restrição, ocultação, correção, restauração e arquivamento preservam histórico.

Em **Problemas**, merge, split, reassignment e undo organizam agrupamentos sem apagar relatos. Toda ação deve ter justificativa.

## Categorias e importação

Mantenha tipos, categorias, subcategorias e aliases sem reescrever relatos antigos.

Importação histórica usa os templates CSV/XLSX e segue: lote → validação → staging → correção versionada → revisão → decisão explícita → publicação. Nunca importe ZIP bruto do WhatsApp ou publique telefone, unidade, nomes integrais e conversa irrelevante.

## Contas oficiais

Resposta oficial exige representação válida, com escopo e período corretos. Revogar representação bloqueia novas ações, preservando o histórico. Retorno relatado por morador continua identificado como atribuído.

## Papéis e permissões

Em **Administradores**:

1. localize a pessoa em **Usuários** e copie o UUID;
2. reautentique com Google;
3. selecione papel ou exceção;
4. informe motivo;
5. aplique e confira auditoria.

Um `deny` individual exige cuidado. Autoelevação, alteração acima do nível permitido e remoção do último Master ativo são bloqueadas.

## Jurídico e privacidade

Versão jurídica publicada é imutável. Correção exige nova versão. Valide texto, hash e DOCX, decida sobre reaceite e use autenticação recente.

Pedidos de privacidade exigem análise, fundamento e histórico. Não faça deleção irrestrita; retenção, segurança, contraditório e direitos podem limitar a medida. Encaminhe questão jurídica complexa a profissional adequado.

## Auditoria, configurações e segurança

Auditoria não é editável pela aplicação. Configurações podem ter efeito imediato e precisam de motivo, teste e reversão.

O fluxo de incidente é:

```text
detectar → conter → investigar → corrigir → recuperar → documentar
```

Nunca registre token, chave, URL assinada ou conteúdo integral. Consulte [SECURITY.md](../SECURITY.md) e [Deploy e recuperação](DEPLOYMENT_AND_RECOVERY.md).

## Rotina recomendada

- **Diária:** verificações, sinalizações, jobs, compromissos e incidentes.
- **Semanal:** importações, privacidade, suspensões, representações e auditoria.
- **Mensal:** backup, Storage, papéis, restore isolado, OAuth, domínio e alertas.

Antes de publicar, execute os gates do README e plano de testes. Não declare **READY FOR PRODUCTION** com requisito V1 sem `ACCEPTED` ou restore obrigatório não validado.
