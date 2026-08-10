begin;
set local search_path = public, extensions;
select no_plan();

select is(
  (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r','p') and not c.relrowsecurity),
  0::bigint,
  'all exposed public tables have RLS enabled'
);

select ok(
  (select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'private' and c.relname = 'user_private_data'),
  'private user data remains protected by deny-by-default RLS'
);

select ok(
  not has_table_privilege('anon', 'private.user_private_data', 'SELECT')
  and not has_table_privilege('authenticated', 'private.user_private_data', 'SELECT'),
  'client roles have no direct access to private user data'
);

select is(
  (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'v'
      and not coalesce(c.reloptions, '{}'::text[]) @> array['security_invoker=true']),
  0::bigint,
  'all public views are security_invoker'
);

select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef),
  0::bigint,
  'no public function is SECURITY DEFINER'
);

select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
      lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where n.nspname = 'private' and a.grantee = 0 and a.privilege_type = 'EXECUTE'
  ),
  'PUBLIC cannot execute private functions'
);

select ok(not has_function_privilege('anon', 'public.create_report(jsonb)', 'EXECUTE'), 'anon cannot execute report creation');
select ok(has_function_privilege('authenticated', 'public.create_report(jsonb)', 'EXECUTE'), 'authenticated role can execute report creation');
select ok(not exists(select 1 from information_schema.columns where table_schema='public' and table_name='community_reports' and column_name in ('author_user_id','affected_unit_id')), 'community projection omits author and unit UUIDs');

insert into auth.users(id,email) values
  ('10000000-0000-0000-0000-000000000001','resident1@example.invalid'),
  ('10000000-0000-0000-0000-000000000002','resident2@example.invalid'),
  ('10000000-0000-0000-0000-000000000003','pending@example.invalid'),
  ('10000000-0000-0000-0000-000000000004','master@example.invalid'),
  ('10000000-0000-0000-0000-000000000005','official@example.invalid'),
  ('10000000-0000-0000-0000-000000000006','case.participant@example.invalid'),
  ('10000000-0000-0000-0000-000000000007','bootstrap.member@example.invalid');

insert into auth.sessions(id,user_id,created_at) values
  ('30000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000004',now());

insert into public.profiles(id,first_name,last_name,display_name,public_identity_preference,access_state,relation_to_condo,currently_resides) values
  ('10000000-0000-0000-0000-000000000001','Pessoa','Um','Pessoa Um','protected','active','resident_owner',true),
  ('10000000-0000-0000-0000-000000000002','Pessoa','Dois','Pessoa Dois','identified','active','tenant',true),
  ('10000000-0000-0000-0000-000000000003','Pessoa','Pendente','Pessoa Pendente','protected','pending_verification','tenant',true),
  ('10000000-0000-0000-0000-000000000004','Pessoa','Master','Pessoa Master','protected','active','resident_owner',true),
  ('10000000-0000-0000-0000-000000000005','Conta','Oficial','Conta Oficial','identified','official','authorized_resident',false),
  ('10000000-0000-0000-0000-000000000006','Parte','Convidada','Parte Convidada','protected','case_restricted','authorized_resident',false),
  ('10000000-0000-0000-0000-000000000007','Pessoa','Bootstrap','Pessoa Bootstrap','protected','pending_verification','resident_owner',true);

insert into private.user_private_data(user_id,google_email)
select id,lower(email) from auth.users;

insert into public.condo_units(id,block_id,unit_label) values
  ('20000000-0000-0000-0000-000000000001',1,'101'),
  ('20000000-0000-0000-0000-000000000002',2,'202'),
  ('20000000-0000-0000-0000-000000000004',4,'404');

insert into public.resident_unit_links(user_id,unit_id,relation_type,verification_status,verified_at) values
  ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','resident_owner','approved',now()),
  ('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','tenant','approved',now()),
  ('10000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000004','resident_owner','approved',now());

insert into public.user_legal_acceptances(user_id,document_version_id,accepted_hash_sha256)
select u.id,v.id,v.content_hash_sha256
from auth.users u cross join public.legal_document_versions v
where u.id in ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000006','10000000-0000-0000-0000-000000000007')
  and v.is_current and v.state='published';

insert into public.user_roles(user_id,role_id,granted_by)
select '10000000-0000-0000-0000-000000000004', id, '10000000-0000-0000-0000-000000000004'
from public.roles where slug='master';

insert into public.verification_requests(
  id,user_id,requested_block_id,requested_unit_label,relation_type,currently_resides,state
) values (
  '50000000-0000-0000-0000-000000000007','10000000-0000-0000-0000-000000000007',10,'01','resident_owner',true,'pending'
);

insert into public.official_representations(id,user_id,role_type,organization,starts_at,status,verified_by,verified_at)
values('40000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000005','administrator','Organização fictícia',now()-interval '1 day','active','10000000-0000-0000-0000-000000000004',now());

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select ok(private.is_verified_resident(), 'approved resident is verified');
select ok(private.has_current_legal_acceptances(), 'approved resident has current legal acceptances');

select lives_ok($sql$
  select * from public.create_report(jsonb_build_object(
    'type','maintenance_request','category','maintenance-infrastructure','subcategory','structures',
    'title','Infiltração fictícia no corredor','description','Descrição inteiramente fictícia, suficiente para testar o fluxo transacional.',
    'occurred_at','2026-08-08T12:00:00Z','is_ongoing',true,'previously_communicated',false,
    'urgency','attention','declared_recurrence',false,'sensitivity','normal','identity_mode','protected',
    'visibility','community','scope','common_area'
  ))
$sql$, 'verified resident can create a community report');

select lives_ok($sql$
  select * from public.create_report(jsonb_build_object(
    'type','information_request','category','administration-management-transparency','subcategory','documents-information',
    'title','Documento fictício restrito','description','Descrição inteiramente fictícia de caso restrito para teste de isolamento.',
    'urgency','routine','sensitivity','sensitive','identity_mode','protected','visibility','restricted','scope','unit'
  ))
$sql$, 'author can create a restricted report');

select is((select count(*) from public.reports), 2::bigint, 'author can read own community and restricted reports');
select lives_ok(
  $$select public.set_report_status(
    (select id from public.reports where title='Infiltração fictícia no corredor'),
    'resolved','Solução fictícia confirmada pelo autor'
  )$$,
  'report author can set a status configured for the report type'
);
select is(
  (select derived_status from public.issues where id=(select issue_id from public.reports where title='Infiltração fictícia no corredor')),
  'resolved'::text,
  'collective issue status is derived from its report statuses'
);
select lives_ok(
  $$select public.record_response(
    (select id from public.reports where title='Infiltração fictícia no corredor'),
    'external_recorded','Prestador fictício','mensagem',now()-interval '1 hour',
    'Retorno externo inteiramente fictício para teste.','Providência fictícia informada',null,null,
    jsonb_build_object('source_label','Prestador fictício','assigned_to','Equipe fictícia','description','Compromisso fictício registrado','assumed_at',now()-interval '1 hour','due_at',now()-interval '1 minute')
  )$$,
  'report author can record attributed external response with a commitment'
);
select lives_ok(
  $$select * from public.create_access_invitation(
    encode(extensions.digest(convert_to('case.participant@example.invalid','UTF8'),'sha256'),'hex'),
    encode(extensions.digest(convert_to('token-ficticio-de-caso','UTF8'),'sha256'),'hex'),
    'case_participant',(select id from public.reports where title='Documento fictício restrito'),
    now()+interval '1 day','{}'::jsonb
  )$$,
  'report author can create a one-case invitation'
);
select lives_ok(
  $$select * from public.reserve_report_attachment(
    (select id from public.reports where title='Documento fictício restrito'),
    'evidencia-ficticia.pdf','application/pdf',128,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'Arquivo inteiramente fictício','sensitive'
  )$$,
  'report author can reserve private evidence metadata'
);
select lives_ok(
  $$insert into storage.objects(bucket_id,name)
    select bucket_id,storage_path from public.attachments
     where uploader_user_id=auth.uid() and upload_status='reserved' and original_filename='evidencia-ficticia.pdf'$$,
  'reserved evidence path can be uploaded once'
);
select lives_ok(
  $$select public.finalize_report_attachment(
    (select id from public.attachments where uploader_user_id=auth.uid() and original_filename='evidencia-ficticia.pdf')
  )$$,
  'uploaded evidence is finalized and added to the timeline'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.community_reports), 1::bigint, 'another verified resident reads only community projection');
select is((select count(*) from public.reports where visibility='restricted'), 0::bigint, 'another resident cannot read restricted report');
select is((select count(*) from public.profiles where id='10000000-0000-0000-0000-000000000001'), 0::bigint, 'resident cannot read another profile PII');
select is((select author_label from public.community_reports limit 1), 'Usuário condominial verificado'::text, 'protected identity label is neutral');
select is((select count(*) from public.search_community_reports('infiltração',30)),1::bigint,'full-text search finds visible community content');
select lives_ok(
  $$select public.set_issue_affected(
    (select issue_id from public.community_reports where title='Infiltração fictícia no corredor'),true,null
  )$$,
  'verified resident can declare a separate affected relationship'
);
select lives_ok(
  $$select public.set_issue_following(
    (select issue_id from public.community_reports where title='Infiltração fictícia no corredor'),true
  )$$,
  'verified resident can separately follow an issue'
);
select lives_ok(
  $$select public.flag_report(
    (select id from public.community_reports where title='Infiltração fictícia no corredor'),
    'personal_data','Sinalização fictícia para testar a fila de moderação'
  )$$,
  'verified resident can flag visible content with a configured reason'
);
select lives_ok(
  $$select public.submit_privacy_request('access','Pedido fictício de acesso aos próprios dados')$$,
  'resident can submit a privacy request without automatic deletion'
);
select lives_ok(
  $$select public.update_notification_preferences('{"own_reports":true,"followed_issues":false,"responses":true,"commitments":true,"email_enabled":true}'::jsonb)$$,
  'resident can configure optional notification preferences'
);
select is((select minimum_group_size from public.community_kpis),3,'analytics exposes the configured privacy threshold');
select is((select reports_count from public.community_kpis),null::bigint,'aggregate groups below three are suppressed');
select throws_ok(
  $$update public.notifications set title='mutated'$$,
  '42501',null,'users cannot rewrite notification content'
);
select ok(
  (select is_affected and is_following from public.current_issue_relationships(
    (select issue_id from public.community_reports where title='Infiltração fictícia no corredor')
  )),
  'affected and following are independent persisted relations'
);
select is(
  (select count(*) from public.issue_affected_users where user_id<>'10000000-0000-0000-0000-000000000002'),
  0::bigint,'community users cannot enumerate other affected user UUIDs'
);
select throws_ok(
  $$select public.record_response(
    (select id from public.community_reports where title='Infiltração fictícia no corredor'),
    'external_recorded','Terceiro','mensagem',now(),'Tentativa indevida de registrar retorno.','Nenhuma',null,null,null
  )$$,
  'P0001','report_author_required','another resident cannot attribute an external response to someone else report'
);
select is(
  (select count(*) from storage.objects where bucket_id='evidence'),0::bigint,
  'another resident cannot download evidence from a restricted report'
);
select throws_ok(
  $$update public.profiles set access_state='active' where id='10000000-0000-0000-0000-000000000002'$$,
  '42501', null, 'resident cannot directly mutate protected profile state'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000005',true);
select ok(private.can_access_report((select id from public.reports where title='Infiltração fictícia no corredor')),'valid official representation can read community report without resident link');
select lives_ok(
  $$select public.record_response(
    (select id from public.reports where title='Infiltração fictícia no corredor'),
    'official',null,null,now(),'Resposta oficial fictícia publicada em teste.','Ação oficial fictícia','40000000-0000-0000-0000-000000000005',null,null
  )$$,
  'verified official account can publish an official response'
);
select lives_ok(
  $$select public.set_official_status(
    (select id from public.reports where title='Infiltração fictícia no corredor'),
    '40000000-0000-0000-0000-000000000005','under_analysis','Análise oficial fictícia'
  )$$,
  'verified official account can append an independent operational status'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000006',true);
select lives_ok(
  $$select * from public.consume_access_invitation('token-ficticio-de-caso')$$,
  'matching Google account can consume a valid case invitation once'
);
select is((select count(*) from public.reports),1::bigint,'case participant reads only the granted restricted report');
select lives_ok(
  $$select public.record_response(
    (select id from public.reports), 'party_statement',null,null,now(),
    'Manifestação fictícia da parte convidada.','Documento fictício apresentado',null,
    (select id from public.case_access_grants where user_id=auth.uid() and revoked_at is null),null
  )$$,
  'case participant can publish a statement only in the granted case'
);
select throws_ok(
  $$select * from public.consume_access_invitation('token-ficticio-de-caso')$$,
  'P0001','invalid_or_expired_invitation','case invitation cannot be reused'
);
reset role;

select is((select private.mark_overdue_commitments()),1,'deadline job marks one due commitment overdue');
select is((select private.mark_overdue_commitments()),0,'deadline job is idempotent on repeated execution');
select is((select count(*) from public.timeline_events where event_type='commitment.overdue'),1::bigint,'overdue transition creates exactly one timeline event');

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
select ok(not private.is_verified_resident(), 'pending resident is not verified');
select is((select count(*) from public.issues), 0::bigint, 'pending resident cannot read community issues');
select throws_ok($sql$
  select * from public.create_report(jsonb_build_object(
    'type','suggestion','category','other','title','Sugestão fictícia pendente',
    'description','Descrição fictícia que não deve ser aceita para usuário pendente.',
    'urgency','routine','identity_mode','protected','visibility','community','scope','common_area',
    'suggested_category_text','Categoria fictícia'
  ))
$sql$, 'P0001', 'community_access_required', 'pending resident cannot create report');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000004","session_id":"30000000-0000-0000-0000-000000000004"}',true);
select ok(public.current_user_has_permission('admins.manage'), 'master receives mapped permission');
select ok(public.current_session_is_recent(), 'fresh authenticated session satisfies reauthentication gate');
select lives_ok(
  $$select public.review_verification_request('50000000-0000-0000-0000-000000000007','approved','Bootstrap fictício auditado')$$,
  'master can create and match a missing catalog unit while approving a verification'
);
select is((select count(*) from public.condo_units where block_id=10 and normalized_label='01'),1::bigint,'bootstrap approval creates the missing unit exactly once');
select is((select state::text from public.verification_requests where id='50000000-0000-0000-0000-000000000007'),'approved','bootstrap verification is approved');
select is((select access_state::text from public.profiles where id='10000000-0000-0000-0000-000000000007'),'active','approved bootstrap member becomes active');
select is((select count(*) from public.audit_logs where action='unit.created' and target_id=(select id from public.condo_units where block_id=10 and normalized_label='01')),1::bigint,'automatic unit creation is audited');
select lives_ok(
  $$select public.set_user_role('10000000-0000-0000-0000-000000000002','moderator','grant','Concessão fictícia de teste')$$,
  'master can grant a lower role after recent authentication'
);
select throws_ok(
  $$select public.set_user_role('10000000-0000-0000-0000-000000000004','administrator','grant','Tentativa fictícia')$$,
  'P0001','self_role_change_forbidden','administrators cannot change their own roles'
);
select lives_ok(
  $$select public.merge_issues(
    (select issue_id from public.reports where title='Infiltração fictícia no corredor'),
    (select issue_id from public.reports where title='Documento fictício restrito'),
    'Merge fictício para validar preservação e reversão'
  )$$,
  'master can merge issues without deleting reports'
);
select lives_ok(
  $$select public.undo_issue_merge((select id from public.issue_merges where undone_at is null order by merged_at desc limit 1),'Desfazer merge fictício de teste')$$,
  'master can undo a merge and restore report assignments'
);
select lives_ok(
  $$select public.split_report_to_new_issue(
    (select id from public.reports where title='Infiltração fictícia no corredor'),
    'Problema fictício separado','Split fictício para teste reversível'
  )$$,
  'master can split one report into a new issue'
);
select lives_ok(
  $$select public.undo_issue_split((select id from public.issue_splits where undone_at is null order by split_at desc limit 1),'Desfazer split fictício de teste')$$,
  'master can undo a split without losing history'
);
select lives_ok(
  $$select public.apply_moderation_action(
    (select id from public.content_flags where state='open' order by created_at limit 1),
    'hide','Ocultação fictícia para permitir revisão'
  )$$,
  'moderator applies a reasoned reversible action'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select lives_ok(
  $$select public.submit_review_request(
    (select id from public.moderation_actions where reverted_at is null order by created_at desc limit 1),false,
    'Solicito revisão fictícia da ação que afetou meu relato'
  )$$,
  'affected report author can request moderation review'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000004","session_id":"30000000-0000-0000-0000-000000000004"}',true);
select lives_ok(
  $$select public.decide_review_request(
    (select id from public.review_requests where state='pending' order by created_at desc limit 1),
    'reversed','Reversão fictícia após análise do pedido'
  )$$,
  'master can decide review and atomically reverse moderation'
);
select lives_ok(
  $$select public.decide_privacy_request(
    (select id from public.privacy_requests where state='received' order by created_at desc limit 1),
    'completed','Cópia fictícia disponibilizada ao titular','Decisão fictícia de teste auditável'
  )$$,
  'master can decide privacy request after recent authentication without automatic deletion'
);
select lives_ok(
  $$select public.manage_taxonomy('location','create',jsonb_build_object('slug','test-location','name','Local fictício','sort_order',999))$$,
  'authorized administrator can create configurable location data'
);
select lives_ok(
  $$select public.manage_taxonomy('location','archive',jsonb_build_object('slug','test-location'))$$,
  'used taxonomy is archived instead of physically deleted'
);
select lives_ok(
  $$select public.create_import_batch('Memória fictícia de teste','csv')$$,
  'master can create a historical import batch'
);
select lives_ok($sql$
  select public.stage_import_items(
    (select id from public.import_batches where source_name='Memória fictícia de teste'),
    jsonb_build_array(
      jsonb_build_object(
        'payload',jsonb_build_object(
          'source_name','Ata fictícia 2025','source_type','minutes','source_reference','ATA-FICTICIA-01',
          'occurred_at','2025-06-10T18:00:00Z','source_actor_key','participante-ficticio-1',
          'record_type','maintenance_request','title','Registro histórico fictício de manutenção',
          'raw_source_text','Texto bruto inteiramente fictício e restrito ao administrador.',
          'published_summary','Resumo público fictício, neutro e suficiente para validar a importação histórica.',
          'category_slug','maintenance-infrastructure','subcategory_slug','structures','scope','common_area',
          'urgency','routine','historical_outcome','outcome_unknown','provenance_notes','Fonte fictícia criada somente para teste automatizado.'
        ),'errors','[]'::jsonb
      ),
      jsonb_build_object(
        'payload',jsonb_build_object(
          'source_name','Nota fictícia para correção','source_type','manual_note','source_reference','NOTA-FICTICIA-02',
          'occurred_at','2025-07-01T12:00:00Z','source_actor_key','participante-ficticio-2',
          'record_type','complaint','title','Registro histórico fictício inicialmente inválido',
          'raw_source_text','Outro texto bruto inteiramente fictício e restrito.',
          'published_summary','curto','category_slug','cleaning-conservation','scope','common_area',
          'urgency','attention','historical_outcome','outcome_unknown','provenance_notes','Fonte fictícia para validar correção em staging.'
        ),'errors',jsonb_build_array('published_summary: mínimo não atendido')
      )
    )
  )
$sql$, 'CSV/XLSX rows enter staging without direct publication');
select is((select count(*) from public.reports where source_origin='historical'),0::bigint,'staging never publishes historical reports');
select is((select count(*) from public.import_staging_items where state='pending_review'),1::bigint,'valid import row awaits explicit review');
select is((select count(*) from public.import_staging_items where state='needs_edit'),1::bigint,'invalid import row is held for correction');
select ok(
  (select payload ? '_source_actor_hash' and not payload ? 'source_actor_key' from public.import_staging_items where state='needs_edit'),
  'staging hashes source actor keys and never retains them in plaintext'
);
select lives_ok(
  $$select public.review_import_item((select id from public.import_staging_items where state='pending_review'),'approved',null,'Revisão fictícia com proveniência conferida')$$,
  'master explicitly approves a valid staged item'
);
select lives_ok(
  $$select * from public.publish_import_item((select id from public.import_staging_items where state='approved'),null)$$,
  'approved item publishes as a new historical issue and report'
);
select matches(
  (select protocol from public.reports where title='Registro histórico fictício de manutenção'),
  '^HIST-[0-9]{4}-[0-9]{6}$','historical publication uses the HIST protocol namespace'
);
select is(
  (select author_label from public.community_reports where title='Registro histórico fictício de manutenção'),
  'Registro histórico importado'::text,'community projection uses the required neutral historical label'
);
select is(
  (select source_origin::text||':'||historical_outcome from public.reports where title='Registro histórico fictício de manutenção'),
  'historical:outcome_unknown'::text,'unknown historical outcomes do not become continuously active native work'
);
select ok(
  exists(select 1 from public.historical_sources s join public.historical_source_actors a on a.id=s.source_actor_id where s.source_reference='ATA-FICTICIA-01' and a.pseudonym~'^historical_actor_[0-9]{4,}$' and s.raw_source_text is not null),
  'restricted provenance and a pseudonymous source actor are preserved'
);
select lives_ok(
  $$select public.review_import_item(
    (select id from public.import_staging_items where state='needs_edit'),'approved',
    jsonb_build_object('published_summary','Resumo público fictício corrigido, neutro e suficiente para publicação histórica.'),
    'Correção fictícia validada antes da aprovação'
  )$$,
  'a corrected invalid row creates provenance without losing its hashed actor or raw source'
);
select lives_ok(
  $$select * from public.publish_import_item(
    (select id from public.import_staging_items where state='approved'),
    (select issue_id from public.reports where title='Registro histórico fictício de manutenção')
  )$$,
  'curator can associate a corrected historical report to an existing issue'
);
select is((select count(*) from public.import_staging_item_versions),1::bigint,'staging edits are append-only versioned records');
select is((select reports_count from public.community_kpis),null::bigint,'historical imports do not silently contaminate native KPI counts');
select is((public.community_kpi_summary('all')->>'reports_count')::bigint,3::bigint,'origin filter explicitly includes all community-visible native and historical reports when requested');
select is((public.community_kpi_summary('historical')->>'reports_count')::bigint,null::bigint,'historical-only groups still obey the minimum privacy threshold');
select is((select state from public.import_batches where source_name='Memória fictícia de teste'),'completed'::text,'batch completes only after every staged item has a terminal state');
select lives_ok(
  $$select public.manage_security_incident(null,jsonb_build_object('severity','medium','status','detected','summary','Incidente técnico inteiramente fictício para teste','systems',jsonb_build_array('aplicação'),'data_categories',jsonb_build_array('metadados técnicos'),'notifications_required',false))$$,
  'master can register an admin-only security incident'
);
select lives_ok(
  $$select public.update_app_setting('max_upload_bytes','10485760'::jsonb,'Ajuste fictício dentro do limite validado')$$,
  'master can update an allowlisted setting with audit reason'
);
select lives_ok(
  $$select public.update_app_setting('rate_limit_reports_per_hour','1'::jsonb,'Redução fictícia para validar aplicação imediata')$$,
  'master can change a rate limit through the audited setting flow'
);
select lives_ok(
  $$select private.enforce_rate_limit('report.create',20)$$,
  'configured rate limit allows the first action'
);
select throws_ok(
  $$select private.enforce_rate_limit('report.create',20)$$,
  'P0001','rate_limit_exceeded','configured rate limit overrides the hard-coded fallback'
);
select lives_ok(
  $$select public.update_app_setting('rate_limit_reports_per_hour','20'::jsonb,'Restauração fictícia após validação do limite')$$,
  'master can restore the configured rate limit with audit history'
);
select throws_ok(
  $$select public.update_app_setting('min_public_aggregate_count','2'::jsonb,'Tentativa fictícia fora do limite')$$,
  'P0001','setting_out_of_range','privacy threshold cannot be reduced below three'
);
select lives_ok(
  $$select public.record_restore_drill(jsonb_build_object('environment','development','backup_started_at',now()-interval '5 minutes','restored_at',now(),'database_verified',true,'storage_inventory_verified',true,'legal_hashes_verified',true,'rls_verified',true,'rpo_minutes',5,'rto_minutes',5,'evidence_reference','drill-local-ficticio-001'))$$,
  'master can record evidence of a non-production restore drill'
);
reset role;
set local role service_role;
select lives_ok(
  $$select public.record_job_result('notification_email','failed',1,0,'provider_test_failure','019fe737-f5bd-72d3-90e4-9fa8f6c1e73e',now()-interval '1 second')$$,
  'service role records a sanitized failed job result'
);
select lives_ok(
  $$select public.record_operational_failure('019fe737-f5bd-72d3-90e4-9fa8f6c1e73e','/api/cron/notifications','send','provider_test_failure',jsonb_build_object('failed_count',1),null)$$,
  'service role records a sanitized operational failure'
);
select throws_ok(
  $$select public.record_operational_failure('019fe737-f5bd-72d3-90e4-9fa8f6c1e73e','/api/test','unsafe','unsafe_metadata',jsonb_build_object('token','never-log'),null)$$,
  'P0001','unsafe_log_metadata','operational logs reject secret-shaped metadata'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.security_incidents),0::bigint,'residents cannot read security incidents');
select is((select count(*) from public.operational_failures),0::bigint,'residents cannot read operational failures');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000004","session_id":"30000000-0000-0000-0000-000000000004"}',true);
select is((select failed_jobs from public.admin_health_summary),1::bigint,'Master health panel aggregates failed jobs');
select is((select recent_failures from public.admin_health_summary),1::bigint,'Master health panel aggregates sanitized failures');
select ok((select last_verified_restore is not null from public.admin_health_summary),'Master health panel shows verified restore evidence');
select lives_ok(
  $$select public.end_resident_link(
    (select id from public.resident_unit_links where user_id='10000000-0000-0000-0000-000000000001' and ended_at is null),
    'Encerramento fictício de teste'
  )$$,
  'authorized administrator can end a resident link'
);
reset role;

select is(
  (select access_state::text from public.profiles where id='10000000-0000-0000-0000-000000000001'),
  'link_ended'::text,
  'ending the final active link removes normal community access'
);
select is(
  (select count(*) from public.reports where author_user_id='10000000-0000-0000-0000-000000000001'),
  2::bigint,
  'ending a link preserves historical report authorship'
);

insert into public.user_permission_overrides(user_id,permission_id,effect,granted_by,reason)
select '10000000-0000-0000-0000-000000000004',id,'deny','10000000-0000-0000-0000-000000000004','Teste'
from public.permissions where slug='admins.manage';
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
select ok(not public.current_user_has_permission('admins.manage'), 'explicit deny overrides master mapping');
reset role;

select throws_ok(
  $$update public.user_roles set revoked_at=now() where user_id='10000000-0000-0000-0000-000000000004'$$,
  'P0001','last_active_master_cannot_be_revoked','last active master cannot be revoked'
);

select throws_ok(
  $$update public.profiles set access_state='suspended', suspended_at=now() where id='10000000-0000-0000-0000-000000000004'$$,
  'P0001','last_active_master_cannot_be_suspended','last active master cannot be suspended'
);

select throws_ok(
  $$update public.legal_document_versions set content_markdown='mutated' where is_current$$,
  'P0001','published_legal_version_is_immutable','published legal content is immutable'
);

select throws_ok(
  $$update public.timeline_events set display_text='mutated' where event_type='report.created'$$,
  'P0001','timeline_events is append-only','timeline is append-only'
);

select ok((select count(*) from public.notifications where essential)>0,'essential governance notifications are queued independently of optional preferences');
select is((select count(*) from private.claim_notification_emails(1)),1::bigint,'email outbox claims one pending notification atomically');
select lives_ok(
  $$select private.complete_notification_email((select id from public.notifications where email_state='sending' limit 1),true)$$,
  'email outbox records successful provider completion'
);

select * from finish();
rollback;
