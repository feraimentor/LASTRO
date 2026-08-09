# Aceite jurídico

Cada política possui uma chave estável e versões imutáveis. O conteúdo canônico é Markdown UTF-8 com LF, Unicode NFC e exatamente uma quebra final. O SHA-256 é calculado sobre esses bytes; o mesmo arquivo gera a página e o DOCX.

Publicação cria uma nova versão e troca is_current transacionalmente. Trigger impede UPDATE/DELETE de versão publicada. Aceite grava user UUID, version UUID, accepted_at do banco, hash da versão e auditoria.

Se a versão corrente exigir reaceite e não houver aceite correspondente, a função de acesso comunitário retorna falso. Políticas públicas, histórico de aceite próprio e logout permanecem disponíveis.
