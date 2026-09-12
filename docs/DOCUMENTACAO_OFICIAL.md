# Documentação oficial — LASTRO V1

## Finalidade

O LASTRO é uma ferramenta de memória comunitária. Permite documentar problemas do condomínio preservando datas, relatos, evidências, retornos, compromissos e histórico. Não decide quem está certo, não certifica irregularidades e não substitui canais urgentes, autoridades, orientação jurídica, síndico ou administradora.

## Público e acesso

Atende moradores e proprietários verificados, representantes autorizados, partes convidadas para caso específico, contas oficiais, moderadores e administradores.

O login Google comprova identidade digital, mas não o vínculo condominial. A comunidade só é liberada após aceite jurídico, perfil, unidade e verificação manual.

```text
Login Google
   ↓
Três aceites jurídicos vigentes
   ↓
Perfil e preferências
   ↓
Bloco e unidade
   ↓
Verificação manual
   ↓
Acesso comunitário
```

O servidor calcula a próxima etapa; abrir uma URL diretamente não contorna os requisitos.

## Conceitos essenciais

- **Relato:** ocorrência individual com protocolo, data, descrição, local, autoria e visibilidade. Complementos não apagam o original.
- **Problema coletivo:** reúne relatos relacionados e possui timeline própria.
- **Afetado:** declara impacto direto; é diferente de apenas acompanhar.
- **Seguidor:** recebe atualizações sem confirmar alegações ou impacto.
- **Estado do morador:** avaliação do autor sobre seu relato.
- **Estado oficial:** posição de representação válida; não sobrescreve o estado do morador.
- **Timeline:** sequência permanente dos eventos relevantes.
- **Evidência:** arquivo privado cuja autorização acompanha o relato.

## Jornada de um relato

1. A pessoa pesquisa antes de registrar.
2. Se já existir problema relacionado, pode vinculá-lo.
3. Caso contrário, surge um problema provisório.
4. O relato recebe protocolo e preserva autoria e texto.
5. Complementos, arquivos, retornos e compromissos entram no histórico.
6. Seguir e declarar impacto continuam relações distintas.
7. Moderação, merge e reorganização preservam proveniência e auditoria.

## Governança

Permissões administrativas são consultadas no banco por UUID, nunca por e-mail espalhado, `is_admin` ou dado antigo do token. Elas podem ser concedidas, negadas e revogadas com auditoria.

As capacidades incluem verificar vínculos, administrar usuários e unidades, moderar, organizar problemas, curar importações, publicar versões jurídicas, atender privacidade e consultar segurança. Operações críticas exigem autenticação recente e o último Master ativo tem proteção contra revogação acidental.

## Privacidade e segurança

- Dados de apresentação ficam separados de e-mail, WhatsApp e notas privadas.
- Identidade protegida não expõe UUID, unidade ou PII à comunidade.
- Tabelas expostas usam RLS e views comunitárias usam `security_invoker`.
- Anexos são privados e links de download têm curta duração.
- Busca respeita visibilidade e métricas pequenas são suprimidas.
- Pedidos de privacidade possuem decisão e histórico próprios.
- Logs evitam tokens, conteúdo integral e PII desnecessária.

Os documentos jurídicos integrais e vigentes ficam em `/legal` na aplicação.

## Moderação e contraditório

Sinalização abre análise, mas não remove automaticamente. Toda ação tem motivo, ator e data e pode receber revisão. Partes citadas podem usar convite restrito a um caso, sem acesso geral à comunidade.

Resposta oficial exige representação válida. Retorno externo registrado por morador recebe rótulo de retorno atribuído e não é transformado em manifestação oficial.

## Indicadores

Indicadores diferenciam relatos, problemas, pessoas, unidades, blocos e origem histórica. Também separam resposta conhecida de resposta oficial, recorrência de persistência e compromissos vigentes de vencidos. Números insuficientes são ocultados para reduzir identificação. Métricas não provam culpa ou causalidade.

## Importação histórica

A V1 aceita entrada manual, CSV e XLSX. Todo material passa por staging, validação e decisão humana. Proveniência é mantida, PII é minimizada e ZIP bruto de WhatsApp não é importado automaticamente.

## Limites da V1

IA, embeddings, importação automática de WhatsApp, aplicativos nativos, votações, feed social e portal público irrestrito não fazem parte da V1. O estado técnico verificável está no [ledger](IMPLEMENTATION_STATUS.md).

## Documentos relacionados

- [Manual do morador](MANUAL_DO_MORADOR.md)
- [Manual da administração](MANUAL_DA_ADMINISTRACAO.md)
- [Base de conhecimento](BASE_DE_CONHECIMENTO.md)
- [Arquitetura](ARCHITECTURE.md)
- [Segurança](../SECURITY.md)
