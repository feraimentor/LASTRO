# Importação histórica

A V1 aceita criação manual, CSV e XLSX estruturado em `/admin/importacoes`, exclusivamente para Master ou `historical_import.manage`. ZIP bruto do WhatsApp não é aceito.

Use os templates em `public/templates`. As 22 colunas, nesta ordem, são: `source_name`, `source_type`, `source_reference`, `occurred_at`, `source_actor_key`, `record_type`, `title`, `raw_source_text`, `published_summary`, `category_slug`, `subcategory_slug`, `suggested_category_text`, `suggested_subcategory_text`, `location_labels`, `scope`, `urgency`, `historical_outcome`, `known_response_text`, `known_response_at`, `commitment_text`, `commitment_due_at` e `provenance_notes`.

Datas usam ISO 8601. Vários locais são separados por ponto e vírgula. `published_summary` deve ser neutro e publicável; o texto bruto fica restrito. `source_actor_key` serve apenas para correlação interna: o servidor grava seu SHA-256 e cria pseudônimo `historical_actor_####`, nunca guarda a chave em texto claro.

Todo item entra em staging. Linhas válidas ficam `pending_review`; inválidas, `needs_edit`. Correções criam versões append-only. Só a decisão explícita `approved` permite publicar. O curador também pode ignorar, criar novo issue histórico ou associar a issue existente. A publicação gera protocolo `HIST-AAAA-NNNNNN`, timeline “Registro histórico importado” e proveniência com data original, fonte e data de importação.

Ausência de prova de desfecho usa `outcome_unknown` e não mantém a ocorrência artificialmente ativa até hoje. A view de desempenho atual considera `native` por padrão; histórico não contamina silenciosamente tempos e contagens atuais.

Privacidade: não publique telefone, nome integral de conversa, número de unidade, conversa irrelevante ou texto literal automaticamente. O staging e as fontes brutas são admin-only e protegidos por RLS. O exemplo dos templates é inteiramente fictício.
