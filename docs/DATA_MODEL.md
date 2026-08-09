# Modelo de dados

Entidades principais usam UUID e FKs reais. Reports, issues, responses, commitments, versões legais, roles históricas, eventos e auditoria não recebem DELETE físico pela aplicação.

## Separações obrigatórias

- profiles contém apresentação comunitária; private.user_private_data contém email, WhatsApp e notas privadas.
- reports contém o relato individual e aponta para issues coletivas.
- report status representa desfecho do autor; official status é histórico separado de representação oficial.
- timeline_events narra o domínio; audit_logs registra governo e segurança.
- attachments contém metadados; o binário fica em Storage privado.
- native e historical são origens distintas para KPIs.
- job_runs e operational_failures guardam telemetria técnica sem conteúdo; security_incidents registra resposta de segurança; backup_restore_drills preserva evidência operacional.

O inventário relacional completo é implementado nas migrations e documentado com comentários SQL. Alterações de assignment de issue, prazo, conteúdo, moderação, vínculo, representação e permissão preservam intervalos e ator responsável.
