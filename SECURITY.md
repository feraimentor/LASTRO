# Política de segurança

## Versões atendidas

Somente a versão implantada na instância oficial e o branch principal recebem correções. Branches, forks e cópias não autorizadas não são suportados.

## Como comunicar uma vulnerabilidade

Não abra issue, discussão ou pull request público com vulnerabilidade explorável, token, dado pessoal, relato real, unidade, UUID de usuário ou URL assinada.

Use **Report a vulnerability** na aba **Security** do repositório. Se o recurso não estiver acessível, utilize o contato de privacidade publicado nos documentos jurídicos da aplicação e identifique o assunto como “SEGURANÇA LASTRO”.

Inclua somente resumo, componente afetado, passos mínimos sem dados de terceiros, impacto provável, horário aproximado e contato seguro. Não realize exfiltração, persistência, indisponibilidade, engenharia social ou teste em contas alheias. Aguarde confirmação antes de ampliar testes.

## Proteção de credenciais

- Secrets nunca entram no Git.
- Chaves de servidor pertencem apenas ao ambiente de hospedagem.
- Chave publicável do Supabase não substitui RLS.
- Links assinados são temporários e não devem ser compartilhados.
- Códigos Google, tokens OAuth e sessões nunca são solicitados por suporte.

Falhas de RLS, exposição de PII, elevação de privilégio, acesso a anexos, bypass de onboarding, convite reutilizável, adulteração de auditoria e vazamento de secrets são prioritários. Esta política não cria programa de recompensa financeira.
