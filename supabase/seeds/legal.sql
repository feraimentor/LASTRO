-- Generated deterministically by scripts/generate-legal-docs.ts.


insert into public.legal_documents(key, title, public_slug) values ($lastro_legal$notifications_communication$lastro_legal$, $lastro_legal$Política de Notificações e Comunicação$lastro_legal$, $lastro_legal$notificacoes-comunicacao$lastro_legal$) on conflict (key) do update set title = excluded.title, public_slug = excluded.public_slug;

insert into public.legal_document_versions(document_id, version, state, published_at, effective_at, content_markdown, content_hash_sha256, requires_reacceptance, is_current, download_path) select id, '1.0', 'published', '2026-08-09T12:00:00-03:00'::timestamptz, '2026-08-09T12:00:00-03:00'::timestamptz, $lastro_legal$# LASTRO — Plataforma Comunitária de Demandas do Condomínio Alto Icaraí

## Política de Notificações e Comunicação

Versão 1.0 • 09 de agosto de 2026 • Documento de governança e uso da plataforma

### Finalidade do conjunto documental

Este documento integra o conjunto obrigatório de políticas da plataforma. A versão vigente deverá permanecer acessível online e o aceite eletrônico versionado será condição para ativação e continuidade do acesso às áreas privadas.

### 1. Objetivo

Esta Política define como a Plataforma Comunitária de Demandas do Condomínio Alto Icaraí comunica eventos aos usuários, registra retornos recebidos fora da aplicação e diferencia manifestações oficiais de informações inseridas pelos próprios moradores. O objetivo é garantir clareza, rastreabilidade e comunicação proporcional, evitando que a plataforma se torne fonte de spam ou substitua indevidamente canais oficiais e de emergência.

### 2. Abrangência

Aplica-se a moradores, proprietários não residentes, representantes autorizados, administradores da plataforma, moderadores e eventuais representantes verificados do síndico, conselho, administradora ou prestadores que utilizem a aplicação.

### 3. Canais de comunicação da plataforma

- Notificações internas na aplicação, incluindo central de notificações e alertas contextuais.
- E-mail transacional para eventos relevantes da conta, da demanda, da segurança, do aceite jurídico e da moderação.
- E-mail opcional de acompanhamento, resumos e avisos sobre bloco, categoria ou problema seguido pelo usuário.
- Integrações futuras, como WhatsApp, somente mediante implementação formal e regras próprias de consentimento e preferência.

### 4. Notificações obrigatórias e opcionais

#### 4.1 Notificações essenciais

Podem ser enviadas independentemente das preferências de comunicação, na medida em que sejam necessárias para segurança, integridade da conta ou funcionamento essencial da plataforma:

- confirmação de autenticação, alteração de segurança ou evento relevante de conta;
- aprovação, solicitação de complemento, rejeição ou revisão do vínculo de morador;
- aplicação de medida de moderação sobre conteúdo do próprio usuário;
- alteração material das políticas obrigatórias e necessidade de novo aceite;
- incidentes de segurança ou privacidade que exijam comunicação ao titular;
- comunicações indispensáveis ao exercício de direitos do usuário na plataforma.

#### 4.2 Notificações configuráveis

- atualizações das próprias demandas;
- novas respostas, complementos ou evidências em problemas acompanhados;
- prazos e compromissos próximos do vencimento ou vencidos;
- problemas relacionados ao bloco ou às áreas selecionadas;
- resumos periódicos, quando ativados pelo usuário.

### 5. Frequência, priorização e anti-spam

A plataforma deve adotar comunicação proporcional ao evento. Notificações de baixa urgência podem ser agrupadas em resumos; alertas críticos podem ser enviados individualmente. O usuário deve poder silenciar categorias opcionais sem perder alertas essenciais. A plataforma não utilizará notificações para campanhas político-eleitorais internas, propaganda comercial não solicitada ou exposição de conflitos pessoais.

### 6. Registro de retorno externo pelo morador

Quando uma resposta for recebida fora da aplicação, o morador poderá registrá-la na timeline da demanda. O formulário deverá solicitar, conforme aplicável:

- quem respondeu ou a organização a que o retorno é atribuído;
- canal utilizado: e-mail, WhatsApp, ligação, presencial, assembleia, comunicado ou outro;
- data em que a comunicação ocorreu;
- texto original, transcrição ou resumo fiel;
- eventual compromisso ou prazo informado;
- evidência opcional ou recomendada, como print, PDF, foto ou arquivo recebido.

O funcionamento da plataforma não depende de o síndico ou a administradora criarem conta. Uma resposta externa registrada por morador nunca será exibida como se tivesse sido publicada diretamente pelo síndico ou pela administradora. A interface deverá mostrar expressamente “Retorno externo registrado pelo morador”.

### 7. Resposta oficial opcional

Síndico, administradora, conselho ou prestadores poderão solicitar reconhecimento de conta oficial. Após verificação pelo Administrador Master ou por pessoa com permissão específica, suas manifestações poderão aparecer como “Resposta oficial publicada na plataforma”. A verificação não concede poderes administrativos nem de moderação.

### 8. Compromissos e prazos

Quando um retorno contiver compromisso verificável ou prazo, o usuário poderá registrá-lo como objeto de acompanhamento. Alterações posteriores de prazo não apagam o prazo anterior. A timeline deverá registrar criação, reprogramação, vencimento, cumprimento e eventual divergência de avaliação do morador.

### 9. Comunicação de risco e emergência

A plataforma não é serviço de emergência. Relatos classificados como possível risco imediato devem exibir aviso para utilização dos canais de emergência e dos meios oficiais adequados. O registro na plataforma serve à documentação e ao acompanhamento, não substitui providência emergencial.

### 10. Preferências e cancelamento

O usuário poderá gerenciar comunicações opcionais no próprio perfil. O cancelamento de alertas opcionais não impede o envio de mensagens essenciais relativas à conta, segurança, privacidade, moderação ou alterações jurídicas obrigatórias.

### 11. Dados utilizados para comunicação

Serão utilizados apenas os dados necessários à entrega e rastreabilidade das comunicações, observando finalidade, necessidade, transparência e segurança. Preferências de notificação, status de leitura, eventos enviados e falhas técnicas podem ser registrados para operação e auditoria.

### 12. Disponibilização online, versionamento e aceite

A versão vigente desta Política deverá estar disponível em rota pública estável da aplicação, sugerida como /legal/notificacoes-comunicacao. O sistema manterá histórico de versões. O aceite desta política integra o portão jurídico do onboarding: após autenticação Google, o usuário deverá abrir ou ter acesso integral ao documento, marcar aceite expresso e confirmar o conjunto das políticas antes da ativação do perfil e do acesso às áreas privadas.

Cada aceite deverá registrar, no mínimo: identificador do usuário autenticado, chave do documento, versão, data/hora, hash da versão aceita e evento de auditoria. Não é necessário armazenar endereço IP apenas para produzir prova do aceite, salvo decisão futura fundamentada de governança e privacidade.

### 13. Alterações desta Política

Mudanças meramente editoriais podem preservar o aceite anterior, desde que a versão registre que não houve alteração material. Mudanças que ampliem finalidades, canais, tratamento de dados, deveres ou direitos deverão ser marcadas como reaceite obrigatório e bloquear temporariamente o acesso às áreas privadas até nova manifestação do usuário.

### 14. Contato

Dúvidas sobre esta Política, notificações ou registros de comunicação poderão ser encaminhadas ao Administrador Master pelo e-mail feraimentor@gmail.com, sem prejuízo de outros canais que venham a ser disponibilizados na própria aplicação.

### Referências normativas e orientativas

- Lei Geral de Proteção de Dados Pessoais – Lei nº 13.709/2018: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm
- Marco Civil da Internet – Lei nº 12.965/2014: https://www.planalto.gov.br/ccivil_03/_ato2011-2014/2014/lei/l12965.htm
- ANPD – Materiais educativos e publicações: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes
- ANPD – Regulamento de Comunicação de Incidente de Segurança: https://www.gov.br/anpd/pt-br/assuntos/noticias/anpd-aprova-o-regulamento-de-comunicacao-de-incidente-de-seguranca

— Fim da Política —
$lastro_legal$, 'e86d037a95fef122bafaa52160e30c3b1b0b0228ac369d436904353c450773cd', true, true, '/legal/notificacoes-comunicacao-v1.0.docx' from public.legal_documents where key = $lastro_legal$notifications_communication$lastro_legal$ on conflict (document_id, version) do nothing;

insert into public.legal_documents(key, title, public_slug) values ($lastro_legal$responsible_use_moderation$lastro_legal$, $lastro_legal$Política de Uso Responsável, Moderação e Proteção contra Abusos$lastro_legal$, $lastro_legal$uso-responsavel-moderacao$lastro_legal$) on conflict (key) do update set title = excluded.title, public_slug = excluded.public_slug;

insert into public.legal_document_versions(document_id, version, state, published_at, effective_at, content_markdown, content_hash_sha256, requires_reacceptance, is_current, download_path) select id, '1.0', 'published', '2026-08-09T12:00:00-03:00'::timestamptz, '2026-08-09T12:00:00-03:00'::timestamptz, $lastro_legal$# LASTRO — Plataforma Comunitária de Demandas do Condomínio Alto Icaraí

## Política de Uso Responsável, Moderação e Proteção contra Abusos

Versão 1.0 • 09 de agosto de 2026 • Documento de governança e uso da plataforma

### Finalidade do conjunto documental

Este documento integra o conjunto obrigatório de políticas da plataforma. A versão vigente deverá permanecer acessível online e o aceite eletrônico versionado será condição para ativação e continuidade do acesso às áreas privadas.

### 1. Objetivo e princípios

Esta Política estabelece as regras de uso responsável da plataforma, os critérios de moderação e as salvaguardas contra abuso, assédio, exposição indevida, acusações irresponsáveis, manipulação de dados e conflitos pessoais. A plataforma existe para registrar problemas, demandas e possíveis irregularidades com rastreabilidade, boa-fé e respeito ao contraditório — não para funcionar como rede social de hostilidade.

- Boa-fé e responsabilidade na descrição dos fatos.
- Separação clara entre fato observado, interpretação, suspeita e acusação.
- Preservação de evidências e memória histórica sem apagamento silencioso.
- Proteção da honra, imagem, privacidade e dados pessoais de terceiros.
- Direito de resposta e contraditório, sem dependência da participação da gestão.
- Moderação motivada, proporcional e auditável.

### 2. Usos permitidos

- registrar reclamações, demandas de manutenção, riscos, pedidos de informação, sugestões e denúncias de possível irregularidade;
- anexar evidências pertinentes;
- registrar retorno recebido externamente, com atribuição correta;
- informar que também é afetado por problema coletivo;
- comentar apenas quando houver contribuição relevante à compreensão ou solução do problema;
- exercer direito de resposta, contestar informações e complementar registros com civilidade.

### 3. Conteúdo proibido ou sujeito a restrição

- ameaças, intimidação, assédio, perseguição, humilhação sistemática ou incitação à violência;
- ofensas pessoais, xingamentos, ataques discriminatórios ou exposição vexatória sem relação necessária com a demanda;
- imputação sabidamente falsa de crime ou divulgação consciente de informação falsa;
- publicação de CPF, documentos, dados financeiros, credenciais, telefone, endereço externo, dados médicos ou outros dados pessoais desnecessários de terceiros;
- exposição de crianças e adolescentes além do estritamente necessário;
- publicação de mídia íntima, material sexual, conteúdo ilegal ou instruções para prática ilícita;
- spam, publicidade, correntes, campanhas ou conteúdo sem relação com a finalidade da plataforma;
- manipulação coordenada, múltiplas contas para inflar apoio, automações abusivas ou registros deliberadamente duplicados;
- fraude documental, adulteração de evidência ou apresentação enganosa de material fora de contexto.

### 4. Como formular acusações e suspeitas

O formulário de denúncia poderá perguntar como o usuário tomou conhecimento do fato: presenciou diretamente, possui documento, recebeu comunicação, ouviu relato de terceiro ou possui apenas indícios. Essa informação compõe o contexto e não equivale a juízo de verdade.

Quando não houver comprovação conclusiva, o usuário deve empregar linguagem compatível com o grau de conhecimento: relato, suspeita, indício, possível irregularidade, segundo documento recebido ou equivalente. A plataforma não certifica automaticamente a veracidade de alegações.

### 5. Evidências

Anexos devem ser pertinentes ao fato relatado e, sempre que possível, conter descrição de contexto e data. A existência de evidência não transforma uma alegação em fato juridicamente comprovado. Arquivos serão armazenados de forma privada, com controles de acesso, e poderão ser restringidos quando contiverem dados pessoais ou conteúdo sensível.

### 6. Identidade protegida

A plataforma poderá permitir que um morador verificado publique com identidade protegida perante a comunidade. A identidade real permanece conhecida internamente e acessível apenas a usuários autorizados quando necessário. O recurso não autoriza abuso, anonimato irresponsável ou impunidade.

### 7. Direito de resposta e contraditório

Pessoas, empresas ou representantes citados poderão solicitar canal de manifestação. Síndico, administradora, conselho e prestadores não são obrigados a criar conta; caso não participem, o morador poderá registrar retornos externos. Caso participem e sejam verificados, suas respostas serão identificadas como oficiais. A plataforma preservará a sequência alegação → evidência → resposta → contrarresposta → desfecho, sem declarar automaticamente quem está certo.

### 8. Moderação

No lançamento, a moderação será exercida pelo Administrador Master. O sistema deverá estar preparado para delegação futura por permissões granulares. A moderação não altera silenciosamente o conteúdo original do morador. As principais ações são:

- solicitar correção ou contextualização;
- restringir visibilidade;
- ocultar temporariamente;
- restaurar conteúdo;
- arquivar duplicidade;
- remover tecnicamente arquivo cuja manutenção gere risco relevante, preservando o log da ação;
- suspender privilégios de publicação ou a conta nos casos cabíveis.

### 9. Motivo e auditoria da moderação

Toda medida relevante deverá registrar administrador responsável, data/hora, motivo, objeto afetado e, quando apropriado, estado anterior e posterior. O conteúdo retirado da visualização não será tratado como se nunca tivesse existido. A aplicação não oferecerá função de edição ou exclusão dos logs de auditoria pela interface comum.

### 10. Denúncia de conteúdo

Usuários poderão denunciar publicação por exposição de dados pessoais, ameaça, ofensa, acusação falsa, conteúdo inadequado, spam ou outro motivo. A denúncia de conteúdo não gera remoção automática; ela encaminha o item à fila de moderação, salvo mecanismos técnicos de proteção imediata em situações excepcionalmente graves.

### 11. Medidas aplicáveis ao usuário

Conforme gravidade, contexto e reincidência, poderão ser adotadas: orientação, advertência, restrição de conteúdo, limitação temporária de publicação, suspensão e, em situações graves, exclusão de acesso comunitário, sempre com registro de motivo. Não é obrigatório seguir progressão quando a gravidade justificar medida imediata.

### 12. Pedido de revisão

O usuário afetado por medida de moderação poderá solicitar revisão fundamentada. Enquanto houver apenas um Administrador Master, a revisão será reavaliada pelo próprio Master e registrada separadamente. Quando existir equipe de confiança, o sistema deverá permitir revisão por administrador distinto sempre que houver disponibilidade e ausência de conflito de interesse.

### 13. Conflito envolvendo administradores

Reclamações sobre o próprio Administrador Master ou outros administradores poderão existir. Nenhuma intervenção administrativa ficará sem auditoria. Com a formação futura da equipe, a governança deverá priorizar análise por pessoa não envolvida no conflito.

### 14. Emergência e ilícitos

A plataforma não substitui polícia, bombeiros, SAMU, concessionárias, canais de emergência, autoridades públicas ou meios oficiais do condomínio. Conteúdo que descreva possível crime ou risco imediato pode exigir orientação para canal competente e tratamento de visibilidade apropriado.

### 15. Responsabilidade do autor

O autor é responsável pelo conteúdo que insere e deve agir com boa-fé, cuidado e respeito aos direitos de terceiros. O exercício do direito de reclamar, fiscalizar ou criticar não autoriza excesso, exposição desnecessária ou prática de ato ilícito. A legislação brasileira prevê responsabilidade civil por dano decorrente de ato ilícito e tipifica crimes contra a honra; por isso, a plataforma privilegia linguagem factual e rastreável.

### 16. Categorias e opção Outros

A inexistência de categoria adequada nunca impedirá o registro. Ao selecionar Outros, o usuário deverá informar obrigatoriamente qual categoria ou subcategoria considera apropriada. A sugestão será enviada à fila administrativa e poderá gerar criação ou reclassificação posterior sem alterar o conteúdo original.

### 17. Disponibilização online, versionamento e aceite

A versão vigente deverá estar acessível em rota pública estável, sugerida como /legal/uso-responsavel-moderacao. O aceite expresso será obrigatório no portão jurídico após o login Google e antes da ativação do perfil. Alterações materiais poderão exigir novo aceite, com bloqueio temporário das áreas privadas até confirmação.

### 18. Contato

Pedidos de revisão, dúvidas de moderação ou comunicações sobre abuso poderão ser encaminhados ao Administrador Master pelo e-mail feraimentor@gmail.com ou por canal próprio da plataforma quando disponível.

### Referências normativas e orientativas

- Código Civil – Lei nº 10.406/2002, especialmente arts. 186, 187 e 927: https://www.planalto.gov.br/ccivil_03/leis/2002/l10406compilada.htm
- Código Penal – Decreto-Lei nº 2.848/1940, especialmente arts. 138 a 145: https://www.planalto.gov.br/ccivil_03/decreto-lei/del2848compilado.htm
- Marco Civil da Internet – Lei nº 12.965/2014: https://www.planalto.gov.br/ccivil_03/_ato2011-2014/2014/lei/l12965.htm
- Lei Geral de Proteção de Dados Pessoais – Lei nº 13.709/2018: https://www.planalto.gov.br/ccivil_03/_ato2011-2014/2014/lei/l13709.htm

— Fim da Política —
$lastro_legal$, '83c8dcd84262a916412c0221070eb35020e52fa3ec91daa3212100c36b055496', true, true, '/legal/uso-responsavel-moderacao-v1.0.docx' from public.legal_documents where key = $lastro_legal$responsible_use_moderation$lastro_legal$ on conflict (document_id, version) do nothing;

insert into public.legal_documents(key, title, public_slug) values ($lastro_legal$privacy_terms$lastro_legal$, $lastro_legal$Política de Privacidade, LGPD e Termos de Uso$lastro_legal$, $lastro_legal$privacidade-termos$lastro_legal$) on conflict (key) do update set title = excluded.title, public_slug = excluded.public_slug;

insert into public.legal_document_versions(document_id, version, state, published_at, effective_at, content_markdown, content_hash_sha256, requires_reacceptance, is_current, download_path) select id, '1.0', 'published', '2026-08-09T12:00:00-03:00'::timestamptz, '2026-08-09T12:00:00-03:00'::timestamptz, $lastro_legal$# LASTRO — Plataforma Comunitária de Demandas do Condomínio Alto Icaraí

## Política de Privacidade, LGPD e Termos de Uso

Versão 1.0 • 09 de agosto de 2026 • Documento de governança e uso da plataforma

### Finalidade do conjunto documental

Este documento integra o conjunto obrigatório de políticas da plataforma. A versão vigente deverá permanecer acessível online e o aceite eletrônico versionado será condição para ativação e continuidade do acesso às áreas privadas.

### 1. Sobre este documento

Este documento reúne a Política de Privacidade e os Termos de Uso da Plataforma Comunitária de Demandas do Condomínio Alto Icaraí. Ele explica quais dados são tratados, para quais finalidades, como são protegidos, quais direitos possuem os titulares e quais condições regem o acesso à plataforma. O aceite dos Termos não equivale a consentimento genérico para todos os tratamentos de dados: cada operação deverá possuir base legal adequada e finalidade definida.

### 2. Responsável inicial pela plataforma

No lançamento, a administração técnica e de governança será centralizada no Administrador Master, autenticado pela conta Google feraimentor@gmail.com. O condomínio, o síndico e a empresa administradora não se tornam automaticamente administradores da plataforma nem controladores conjuntos apenas por serem mencionados ou por eventualmente exercerem direito de resposta. Papéis jurídicos de tratamento deverão refletir a realidade de cada operação e poderão ser revistos à medida que a governança evoluir.

### 3. Quem pode usar

A plataforma é privada. O acesso comunitário completo será destinado a pessoas autenticadas pelo Google e com vínculo condominial verificado conforme as regras da aplicação. Proprietários não residentes, inquilinos, familiares/residentes autorizados e representantes poderão possuir tipos de vínculo distintos.

### 4. Portão jurídico e formação da conta

O fluxo será: autenticação Google → apresentação integral das três políticas obrigatórias → aceite expresso e versionado → criação/ativação do perfil da plataforma → solicitação/verificação de vínculo → acesso conforme permissões. Tecnicamente, o provedor de autenticação pode criar uma identidade básica antes do aceite; essa identidade não receberá acesso comunitário nem perfil ativo até a conclusão do portão jurídico.

O sistema deverá exigir aceite separado e identificável da Política de Notificações e Comunicação, da Política de Uso Responsável e Moderação e desta Política de Privacidade/Termos. Os três aceites são necessários para prosseguir. Se o usuário não concordar, poderá encerrar o fluxo e sair.

### 5. Dados pessoais tratados

- Dados de autenticação Google: identificador, e-mail, nome e foto de perfil quando disponibilizados pelo provedor.
- Dados cadastrais: nome, sobrenome, preferências e eventual telefone/WhatsApp, quando fornecido.
- Dados de vínculo: bloco, apartamento/unidade, tipo de relação com o imóvel, residência atual, datas e estado de verificação.
- Conteúdo do usuário: reclamações, demandas, denúncias de possível irregularidade, pedidos de informação, sugestões, comentários, avaliações de desfecho e complementos.
- Evidências e mídias: fotos, vídeos, áudios, PDFs, prints e outros arquivos enviados pelo usuário.
- Registros de acompanhamento: respostas externas, respostas oficiais, compromissos, prazos, recorrências, seguidores e declaração também sou afetado.
- Registros de segurança e governança: aceites jurídicos, logs de auditoria, moderação, permissões, notificações, falhas técnicas e eventos necessários à segurança.

### 6. Dados sensíveis e de terceiros

A finalidade ordinária da plataforma não exige coleta sistemática de dados pessoais sensíveis. Contudo, usuários podem inserir conteúdo que revele saúde, opinião política, religião, biometria ou outras informações sensíveis, bem como dados de terceiros. A aplicação deverá desencorajar o envio de dados desnecessários, oferecer alertas contextuais e aplicar visibilidade restrita ou moderação quando adequado.

### 7. Finalidades do tratamento

- autenticar usuários e impedir acesso comunitário não autorizado;
- verificar vínculo com o condomínio;
- receber, organizar, documentar e acompanhar problemas e demandas;
- preservar cronologia, evidências, respostas, compromissos e histórico de recorrência;
- gerar indicadores agregados de transparência, acompanhamento e memória institucional;
- viabilizar moderação, prevenção de abuso, segurança e auditoria;
- enviar comunicações essenciais e opcionais conforme preferências;
- cumprir obrigações legais, regulatórias e ordens válidas de autoridades;
- permitir exercício regular de direitos e defesa em procedimentos administrativos ou judiciais, quando aplicável.

### 8. Bases legais

As bases legais serão definidas conforme a operação concreta e registradas na governança de dados. Podem incluir consentimento para funcionalidades opcionais; execução dos Termos e procedimentos relacionados ao uso solicitado pelo titular; legítimo interesse, mediante avaliação e salvaguardas, para segurança, prevenção de fraude e funcionamento comunitário; cumprimento de obrigação legal ou regulatória; exercício regular de direitos; e outras hipóteses previstas na LGPD. O sistema não tratará o aceite desta Política como autorização ilimitada.

### 9. Minimização e separação de dados

A arquitetura deverá separar dados públicos internos de dados privados. E-mail, WhatsApp, dados de verificação e outras informações privadas não serão disponibilizados a moradores comuns. Apartamento e bloco poderão ser ocultados em publicações protegidas. O telefone deverá ser opcional no MVP, salvo necessidade operacional futura claramente justificada.

### 10. Compartilhamento e operadores tecnológicos

Para funcionamento técnico, dados podem ser tratados por provedores de infraestrutura e autenticação, como Google, Supabase e Vercel, além de eventual provedor de e-mail transacional. O uso desses fornecedores deverá observar contratos, configurações de segurança, minimização e avaliação de transferências internacionais quando aplicável.

### 11. Transferência internacional

Alguns provedores tecnológicos podem processar dados fora do Brasil. A plataforma deverá mapear os fluxos e adotar mecanismos compatíveis com a LGPD e com a regulamentação da ANPD sobre transferência internacional de dados, incluindo salvaguardas contratuais ou outros mecanismos válidos quando exigidos.

### 12. Armazenamento de evidências

Mídias comprobatórias serão armazenadas em repositório privado, sem URL pública permanente. O acesso deverá obedecer às mesmas permissões do conteúdo relacionado. O sistema registrará metadados necessários, incluindo nome original, tipo, tamanho, autor, data e hash de integridade quando implementado. Substituição silenciosa de evidência não será permitida.

### 13. Retenção e histórico institucional

Registros publicados integram a memória institucional e não serão apagados apenas porque o autor saiu do condomínio. A retenção deverá ser proporcional à finalidade, aos direitos dos titulares e à necessidade de preservar histórico, auditoria, defesa e integridade dos indicadores. Conteúdo retirado da visualização poderá continuar preservado de forma restrita quando houver justificativa legítima. Políticas específicas de retenção serão configuráveis pelo Master e revisadas periodicamente.

### 14. Direitos do titular

Nos termos da LGPD e conforme aplicável, o titular poderá solicitar confirmação de tratamento, acesso, correção, anonimização, bloqueio ou eliminação de dados inadequados ou excessivos, informação sobre compartilhamento, portabilidade quando regulamentada e cabível, oposição e revogação de consentimento quando o tratamento se basear nessa hipótese. Solicitações serão analisadas considerando também deveres de retenção e direitos de terceiros.

### 15. Segurança da informação

- autenticação Google e verificação independente do vínculo condominial;
- Row Level Security no banco de dados, com autorização efetiva no servidor e no PostgreSQL;
- Storage privado para evidências e acesso temporário/autorizado;
- permissões granulares para administradores;
- logs de auditoria append-only pela interface;
- segregação entre dados comunitários e dados privados;
- gestão de segredos exclusivamente no servidor;
- backups, monitoramento, recuperação e testes periódicos de permissões.

### 16. Incidentes de segurança

A plataforma deverá manter procedimento de identificação, contenção, análise, documentação e resposta a incidentes. Quando houver incidente com risco ou dano relevante nos termos da regulamentação aplicável, serão avaliadas as comunicações cabíveis aos titulares e à ANPD. O registro interno de incidentes deverá ser preservado conforme requisitos legais e de governança.

### 17. Termos de uso – natureza do serviço

A plataforma é uma ferramenta comunitária privada de documentação e acompanhamento. Não é canal oficial do condomínio, não substitui assembleias, notificações formais, administradora, autoridades, serviços públicos ou canais de emergência, salvo se futuramente houver reconhecimento formal e específico de determinada funcionalidade por parte competente.

### 18. Termos de uso – responsabilidades do usuário

- fornecer dados cadastrais verdadeiros e manter o vínculo atualizado;
- proteger sua conta Google e não compartilhar sessão;
- registrar conteúdo de boa-fé e respeitar direitos de terceiros;
- não tentar contornar permissões, extrair dados de outros usuários ou explorar vulnerabilidades;
- não usar a plataforma para spam, perseguição, fraude, manipulação ou exposição desnecessária;
- cumprir a Política de Uso Responsável e as decisões de moderação aplicáveis, sem prejuízo do pedido de revisão.

### 19. Disponibilidade e continuidade

A plataforma buscará disponibilidade e integridade compatíveis com seu caráter comunitário, mas pode passar por manutenção, indisponibilidade técnica ou falha de terceiros. O sistema deverá possuir backups, monitoramento e plano de recuperação, sem promessa de disponibilidade ininterrupta.

### 20. Suspensão e encerramento de acesso

O acesso poderá ser limitado quando o vínculo condominial terminar, houver risco de segurança, abuso grave ou violação relevante das políticas. A suspensão não apaga automaticamente registros históricos já integrados à memória da plataforma. O usuário poderá solicitar revisão conforme as regras de moderação.

### 21. Alteração das políticas

Toda versão terá número, data e registro histórico. Mudanças materiais que afetem direitos, deveres, finalidades ou formas de tratamento serão identificadas como reaceite obrigatório. O sistema bloqueará o acesso privado até que o usuário aceite a versão vigente ou encerre a sessão.

### 22. Disponibilização online e prova de aceite

A versão vigente deverá estar acessível publicamente em rota estável, sugerida como /legal/privacidade-termos, com opção de download. O banco manterá tabelas específicas para versões de documentos e aceites. Cada aceite conterá usuário, documento, versão, data/hora, hash do conteúdo e registro de auditoria. O histórico de aceites será consultável pelo próprio usuário e pelo Master conforme permissões.

### 23. Canal para privacidade e direitos

Enquanto não houver outro canal dedicado, solicitações relativas a dados pessoais e privacidade poderão ser encaminhadas a feraimentor@gmail.com. A governança poderá futuramente designar encarregado ou canal específico, conforme necessidade e enquadramento jurídico.

### 24. Legislação aplicável

Este documento é interpretado à luz da legislação brasileira, especialmente da Lei Geral de Proteção de Dados Pessoais, do Marco Civil da Internet e das normas da ANPD aplicáveis. Questões não resolvidas por estes Termos deverão ser tratadas pelos canais de governança e, quando necessário, pelos meios legais competentes.

### Referências normativas e orientativas

- Lei Geral de Proteção de Dados Pessoais – Lei nº 13.709/2018: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm
- Marco Civil da Internet – Lei nº 12.965/2014: https://www.planalto.gov.br/ccivil_03/_ato2011-2014/2014/lei/l12965.htm
- ANPD – Regulamento para agentes de tratamento de pequeno porte – Resolução CD/ANPD nº 2/2022: https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-2-de-27-de-janeiro-de-2022
- ANPD – Segurança da informação para agentes de tratamento de pequeno porte: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia-vf.pdf
- ANPD – Regulamento de Comunicação de Incidente de Segurança – Resolução nº 15/2024: https://www.gov.br/anpd/pt-br/assuntos/noticias/anpd-aprova-o-regulamento-de-comunicacao-de-incidente-de-seguranca
- ANPD – Transferência Internacional de Dados – Resolução nº 19/2024: https://www.gov.br/anpd/pt-br/assuntos/assuntos-internacionais/transferencia-internacional-de-dados

— Fim da Política e dos Termos —
$lastro_legal$, 'c4d6c908dbc00a696cd2ff07b6157fefa886a07d81fc976ce513ea6b5ae17f6f', true, true, '/legal/privacidade-termos-v1.0.docx' from public.legal_documents where key = $lastro_legal$privacy_terms$lastro_legal$ on conflict (document_id, version) do nothing;
