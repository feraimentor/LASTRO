-- Structural seed only. No real users, reports or historical complaints.
insert into public.blocks(id, label)
select n, 'Bloco ' || n from generate_series(1, 14) as n
on conflict (id) do update set label = excluded.label;

insert into public.report_types(slug, name, sort_order) values
  ('complaint', 'Reclamação', 10),
  ('maintenance_request', 'Demanda de manutenção', 20),
  ('possible_irregularity', 'Denúncia de possível irregularidade', 30),
  ('information_request', 'Pedido de informação', 40),
  ('suggestion', 'Sugestão', 50),
  ('safety_risk', 'Segurança ou risco', 60)
on conflict (slug) do update set name = excluded.name, sort_order = excluded.sort_order;

insert into public.categories(slug, name, sort_order) values
  ('administration-management-transparency', 'Administração, gestão e transparência', 10),
  ('access-control-concierge', 'Controle de acesso e portaria', 20),
  ('security-risk-prevention', 'Segurança e prevenção de riscos', 30),
  ('maintenance-infrastructure', 'Manutenção e infraestrutura', 40),
  ('energy-electrical', 'Energia e instalações elétricas', 50),
  ('water-sewage-drainage', 'Água, esgoto e drenagem', 60),
  ('cleaning-conservation', 'Limpeza e conservação', 70),
  ('environmental-health-pests', 'Saúde ambiental e pragas', 80),
  ('leisure-common-areas', 'Lazer, esporte e áreas comuns', 90),
  ('pets', 'Animais domésticos', 100),
  ('parking-vehicles', 'Estacionamento e veículos', 110),
  ('construction-renovation', 'Obras e reformas', 120),
  ('gardens-green-areas', 'Jardins, árvores e áreas verdes', 130),
  ('coexistence-rules', 'Convivência e cumprimento de regras', 140),
  ('commerce-internal-services', 'Comércio, concessões e serviços internos', 150),
  ('other', 'Outros', 999)
on conflict (slug) do update set name = excluded.name, sort_order = excluded.sort_order;

with seed(category_slug, slug, name, sort_order) as (values
  ('administration-management-transparency','management-communication','Comunicação da gestão',10),
  ('administration-management-transparency','response-delay','Ausência ou demora de resposta',20),
  ('administration-management-transparency','accounts','Prestação de contas',30),
  ('administration-management-transparency','documents-information','Documentos e informações',40),
  ('administration-management-transparency','assemblies-meetings','Assembleias e reuniões',50),
  ('administration-management-transparency','contracts-purchases-budgets','Contratos, compras e orçamentos',60),
  ('administration-management-transparency','decision-compliance','Cumprimento de decisões',70),
  ('administration-management-transparency','commitment-compliance','Cumprimento de compromissos/promessas',80),
  ('administration-management-transparency','provider-oversight','Fiscalização de prestadores',90),
  ('access-control-concierge','intercom','Interfone / porteiro eletrônico',10),
  ('access-control-concierge','gates','Portões',20),
  ('access-control-concierge','locks','Fechaduras',30),
  ('access-control-concierge','tags-keys-controls','Tags, chaves e controles',40),
  ('access-control-concierge','visitors','Visitantes',50),
  ('access-control-concierge','providers','Prestadores',60),
  ('access-control-concierge','concierge','Portaria / guarita',70),
  ('access-control-concierge','access-registration','Cadastro e autorização de acesso',80),
  ('security-risk-prevention','cctv','Câmeras / CFTV',10),
  ('security-risk-prevention','security-lighting','Iluminação de segurança',20),
  ('security-risk-prevention','walls-fences','Muros, grades e cercas',30),
  ('security-risk-prevention','fire-safety','Segurança contra incêndio',40),
  ('security-risk-prevention','extinguishers','Extintores',50),
  ('security-risk-prevention','hydrants','Mangueiras / hidrantes',60),
  ('security-risk-prevention','emergency-routes','Rotas e saídas de emergência',70),
  ('security-risk-prevention','electrical-risk','Risco elétrico',80),
  ('security-risk-prevention','structural-risk','Risco estrutural',90),
  ('security-risk-prevention','security-occurrence','Ocorrência ou ameaça à segurança',100),
  ('maintenance-infrastructure','floors-sidewalks','Pisos e calçadas',10),
  ('maintenance-infrastructure','internal-roads','Vias internas',20),
  ('maintenance-infrastructure','walls-coatings','Paredes e revestimentos',30),
  ('maintenance-infrastructure','painting','Pintura',40),
  ('maintenance-infrastructure','roofs','Telhados e coberturas',50),
  ('maintenance-infrastructure','infiltration','Infiltrações',60),
  ('maintenance-infrastructure','structures','Estruturas',70),
  ('maintenance-infrastructure','common-equipment','Equipamentos de áreas comuns',80),
  ('maintenance-infrastructure','preventive-maintenance','Manutenção preventiva',90),
  ('maintenance-infrastructure','corrective-maintenance','Manutenção corretiva',100),
  ('energy-electrical','power-outage','Falta de energia',10),
  ('energy-electrical','power-fluctuation','Oscilação de energia',20),
  ('energy-electrical','wiring','Fiação',30),
  ('energy-electrical','electrical-panels','Quadros elétricos',40),
  ('energy-electrical','common-lighting','Iluminação de áreas comuns',50),
  ('energy-electrical','lampposts','Postes / luminárias',60),
  ('energy-electrical','utility-company','Problemas atribuídos à concessionária',70),
  ('water-sewage-drainage','water-outage','Falta de água',10),
  ('water-sewage-drainage','water-tank','Caixa d''água / reservatório',20),
  ('water-sewage-drainage','pumps','Bombas',30),
  ('water-sewage-drainage','leaks','Vazamentos',40),
  ('water-sewage-drainage','sewage','Esgoto',50),
  ('water-sewage-drainage','drainage-flooding','Drenagem / alagamento',60),
  ('water-sewage-drainage','water-pressure','Pressão de água',70),
  ('cleaning-conservation','common-cleaning','Limpeza de áreas comuns',10),
  ('cleaning-conservation','waste','Lixo',20),
  ('cleaning-conservation','irregular-disposal','Descarte irregular',30),
  ('cleaning-conservation','debris','Entulho',40),
  ('cleaning-conservation','animal-feces','Fezes de animais',50),
  ('cleaning-conservation','sanitization','Higienização',60),
  ('cleaning-conservation','general-conservation','Conservação geral',70),
  ('environmental-health-pests','rodents','Ratos / roedores',10),
  ('environmental-health-pests','cockroaches','Baratas',20),
  ('environmental-health-pests','mosquitoes','Mosquitos',30),
  ('environmental-health-pests','insects','Insetos',40),
  ('environmental-health-pests','bats','Morcegos',50),
  ('environmental-health-pests','pigeons','Pombos',60),
  ('environmental-health-pests','other-animals','Outros animais',70),
  ('environmental-health-pests','pest-control','Dedetização',80),
  ('environmental-health-pests','rodent-control','Desratização',90),
  ('environmental-health-pests','sanitary-condition','Condição sanitária',100),
  ('leisure-common-areas','field','Campo',10),
  ('leisure-common-areas','playground','Parquinho',20),
  ('leisure-common-areas','court','Quadra',30),
  ('leisure-common-areas','hall','Salão',40),
  ('leisure-common-areas','childrens-areas','Espaços infantis',50),
  ('leisure-common-areas','sports-equipment','Equipamentos esportivos',60),
  ('leisure-common-areas','leisure-lighting','Iluminação de área de lazer',70),
  ('leisure-common-areas','conservation','Conservação',80),
  ('leisure-common-areas','area-use','Uso da área',90),
  ('pets','uncollected-feces','Fezes não recolhidas',10),
  ('pets','uncontrolled-animal','Animal sem controle',20),
  ('pets','muzzle','Focinheira',30),
  ('pets','irregular-circulation','Circulação irregular',40),
  ('pets','common-area-use','Uso de áreas comuns',50),
  ('pets','noise','Barulho',60),
  ('pets','risk-aggressiveness','Risco/agressividade',70),
  ('pets','rule-enforcement','Fiscalização das regras',80),
  ('parking-vehicles','space-occupation','Falta ou ocupação de vaga',10),
  ('parking-vehicles','irregular-space','Vaga irregular',20),
  ('parking-vehicles','visitors','Visitantes',30),
  ('parking-vehicles','unregistered-vehicle','Veículo não cadastrado',40),
  ('parking-vehicles','overnight','Pernoite',50),
  ('parking-vehicles','internal-circulation','Circulação interna',60),
  ('parking-vehicles','speed','Velocidade',70),
  ('parking-vehicles','abandoned-vehicle','Veículo abandonado',80),
  ('parking-vehicles','enforcement','Fiscalização',90),
  ('construction-renovation','unannounced-work','Obra sem comunicação',10),
  ('construction-renovation','noise','Barulho',20),
  ('construction-renovation','irregular-hours','Horário irregular',30),
  ('construction-renovation','work-safety','Segurança da obra',40),
  ('construction-renovation','art-rrt','ART/RRT/documentação',50),
  ('construction-renovation','debris','Entulho',60),
  ('construction-renovation','common-area-work','Obra em área comum',70),
  ('construction-renovation','unit-collective-impact','Obra em unidade com impacto coletivo',80),
  ('gardens-green-areas','high-grass','Mato alto',10),
  ('gardens-green-areas','mowing','Capina / roçagem',20),
  ('gardens-green-areas','pruning','Poda',30),
  ('gardens-green-areas','risky-tree','Árvore com risco',40),
  ('gardens-green-areas','branches','Galhos',50),
  ('gardens-green-areas','gardening','Jardinagem',60),
  ('gardens-green-areas','vegetation-electrical-grid','Vegetação próxima à rede elétrica',70),
  ('gardens-green-areas','conservation','Conservação',80),
  ('coexistence-rules','noise','Barulho',10),
  ('coexistence-rules','improper-common-area-use','Uso indevido de área comum',20),
  ('coexistence-rules','children-common-areas','Crianças e áreas comuns',30),
  ('coexistence-rules','antisocial-behavior','Comportamento antissocial',40),
  ('coexistence-rules','regulation-breach','Descumprimento de regulamento',50),
  ('coexistence-rules','enforcement','Fiscalização',60),
  ('coexistence-rules','resident-conflicts','Conflitos entre moradores',70),
  ('commerce-internal-services','internal-commerce','Lanchonete / comércio interno',10),
  ('commerce-internal-services','service-quality','Qualidade do serviço',20),
  ('commerce-internal-services','hygiene','Higiene',30),
  ('commerce-internal-services','operations','Funcionamento',40),
  ('commerce-internal-services','contract-concession','Contrato / concessão',50),
  ('commerce-internal-services','service','Atendimento',60),
  ('commerce-internal-services','third-party-provider','Prestador terceirizado',70),
  ('commerce-internal-services','possible-irregularity','Possível irregularidade',80)
), expanded as (
  select c.id as category_id, seed.slug, seed.name, seed.sort_order
  from seed join public.categories c on c.slug = seed.category_slug
  union all
  select c.id, 'other', 'Outros', 999 from public.categories c where c.slug <> 'other'
)
insert into public.subcategories(category_id, slug, name, sort_order)
select category_id, slug, name, sort_order from expanded
on conflict (category_id, slug) do update set name = excluded.name, sort_order = excluded.sort_order;

insert into public.locations(slug, label, sort_order) values
  ('main-entrance','Entrada principal',10), ('concierge','Portaria',20),
  ('parking','Estacionamento',30), ('field','Campo',40), ('playground','Parquinho',50),
  ('external-areas','Áreas externas',60), ('snack-bar','Lanchonete',70), ('other','Outros',999)
on conflict (slug) do update set label = excluded.label, sort_order = excluded.sort_order;

with alias_seed(alias, category_slug, subcategory_slug) as (values
  ('rato','environmental-health-pests','rodents'),
  ('porteiro','access-control-concierge','intercom'),
  ('interfone','access-control-concierge','intercom'),
  ('luz','energy-electrical','common-lighting'),
  ('dedetização','environmental-health-pests','pest-control'),
  ('portão','access-control-concierge','gates'),
  ('art','construction-renovation','art-rrt')
)
insert into public.category_aliases(alias, category_id, subcategory_id)
select a.alias, c.id, s.id from alias_seed a
join public.categories c on c.slug = a.category_slug
left join public.subcategories s on s.category_id = c.id and s.slug = a.subcategory_slug
where not exists (select 1 from public.category_aliases x where x.alias = a.alias and x.category_id = c.id);

insert into public.permissions(slug, description) values
  ('residents.verify','Verificar ou rejeitar vínculos'), ('residents.suspend','Suspender acessos'),
  ('units.manage','Gerenciar unidades'), ('moderation.review','Analisar moderação'),
  ('moderation.restrict','Restringir conteúdo'), ('moderation.restore','Restaurar conteúdo'),
  ('sensitive_content.view','Ver conteúdo sensível'), ('categories.manage','Gerenciar taxonomia'),
  ('issues.merge','Mesclar issues'), ('issues.split','Separar issues'),
  ('official_accounts.verify','Verificar contas oficiais'), ('historical_import.manage','Gerenciar importação histórica'),
  ('reports.export','Exportar relatórios'), ('private_data.view','Ver dados privados'),
  ('audit.view','Consultar auditoria'), ('admins.manage','Gerenciar administradores'),
  ('legal_documents.manage','Gerenciar documentos jurídicos'), ('settings.manage','Gerenciar configurações')
on conflict (slug) do update set description = excluded.description;

insert into public.roles(slug, name, level, is_system) values
  ('resident','Morador',10,true), ('official','Conta oficial',20,true),
  ('moderator','Moderador',50,true), ('administrator','Administrador',80,true), ('master','Master',100,true)
on conflict (slug) do update set name = excluded.name, level = excluded.level;

insert into public.role_permissions(role_id, permission_id)
select r.id, p.id from public.roles r cross join public.permissions p where r.slug = 'master'
on conflict do nothing;

insert into public.app_settings(key, value, description) values
  ('min_public_aggregate_count','3'::jsonb,'Limiar mínimo de privacidade estatística'),
  ('rate_limit_reports_per_hour','20'::jsonb,'Limite anti-automação para reports'),
  ('rate_limit_uploads_per_hour','50'::jsonb,'Limite anti-automação para uploads'),
  ('rate_limit_relations_per_hour','100'::jsonb,'Limite anti-automação para follow/affected'),
  ('max_upload_bytes','52428800'::jsonb,'Tamanho máximo de evidência')
on conflict (key) do update set value = excluded.value, description = excluded.description;

-- Status configured per report type.
with status_seed(type_slug, slug, label, sort_order, terminal) as (values
  ('complaint','awaiting-response','Aguardando resposta',10,false),
  ('complaint','answered-awaiting-solution','Respondida, aguardando solução',20,false),
  ('complaint','monitoring','Em acompanhamento',30,false),
  ('complaint','resolved','Resolvida',40,true), ('complaint','partially-resolved','Resolvida parcialmente',50,true),
  ('complaint','unresolved','Não resolvida',60,true), ('complaint','promise-only','Ficou somente na promessa',70,true),
  ('complaint','no-longer-applicable','Não se aplica mais',80,true),
  ('maintenance_request','awaiting-response','Aguardando resposta',10,false),
  ('maintenance_request','answered-awaiting-solution','Respondida, aguardando solução',20,false),
  ('maintenance_request','monitoring','Em acompanhamento',30,false),
  ('maintenance_request','resolved','Resolvida',40,true), ('maintenance_request','partially-resolved','Resolvida parcialmente',50,true),
  ('maintenance_request','unresolved','Não resolvida',60,true), ('maintenance_request','promise-only','Ficou somente na promessa',70,true),
  ('maintenance_request','no-longer-applicable','Não se aplica mais',80,true),
  ('safety_risk','awaiting-response','Aguardando resposta',10,false), ('safety_risk','monitoring','Em acompanhamento',30,false),
  ('safety_risk','resolved','Resolvida',40,true), ('safety_risk','partially-resolved','Resolvida parcialmente',50,true),
  ('safety_risk','unresolved','Não resolvida',60,true), ('safety_risk','no-longer-applicable','Não se aplica mais',80,true),
  ('information_request','awaiting-response','Aguardando resposta',10,false),
  ('information_request','fully-answered','Respondido integralmente',20,true),
  ('information_request','partially-answered','Respondido parcialmente',30,true),
  ('information_request','no-recorded-response','Sem resposta registrada',40,true),
  ('information_request','closed','Encerrado',50,true),
  ('suggestion','presented','Apresentada',10,false), ('suggestion','under-consideration','Em consideração',20,false),
  ('suggestion','accepted','Aceita',30,false), ('suggestion','not-adopted','Não adotada',40,true),
  ('suggestion','implemented','Implementada',50,true), ('suggestion','closed','Encerrada',60,true),
  ('possible_irregularity','registered-restricted','Registrada/restrita',10,false),
  ('possible_irregularity','under-moderation','Em moderação',20,false),
  ('possible_irregularity','published','Publicada',30,false),
  ('possible_irregularity','statement-received','Manifestação recebida',40,false),
  ('possible_irregularity','monitoring','Em acompanhamento',50,false),
  ('possible_irregularity','closed-without-conclusion','Encerrada sem conclusão',60,true),
  ('possible_irregularity','archived','Arquivada',70,true)
)
insert into public.report_status_definitions(report_type_id, slug, label, sort_order, is_terminal)
select rt.id, s.slug, s.label, s.sort_order, s.terminal from status_seed s
join public.report_types rt on rt.slug = s.type_slug
on conflict (report_type_id, slug) do update set label = excluded.label, sort_order = excluded.sort_order, is_terminal = excluded.is_terminal;
