begin;
select plan(15);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values ('af410000-0000-4000-8000-000000000001','authenticated','authenticated','application-admin@demo.aptohire.test',now(),extensions.crypt('unused',extensions.gen_salt('bf')),'{}'::jsonb,'{}'::jsonb,now(),now());
insert into public.profiles(id,role) values ('af410000-0000-4000-8000-000000000001','admin');

select has_function('public','lookup_submit_application_idempotency',array['uuid','text'],'idempotency lookup RPC exists');
select has_function('public','submit_application',array['uuid','text','jsonb'],'atomic application RPC exists');
select ok(has_function_privilege('service_role','public.submit_application(uuid,text,jsonb)','execute'),'service role can submit applications');
select ok(not has_function_privilege('anon','public.submit_application(uuid,text,jsonb)','execute'),'anonymous callers cannot invoke the database RPC directly');
set local role service_role;

select matches((public.submit_application('af410000-0000-4000-8000-000000000010',repeat('a',64),
'{"type":"university","institution_name":"Fictional Delta University","short_name":"FDU","kind":"university","tier":"tier2","city":"Jaipur","state":"Rajasthan","email_domains":["fdu.example.test"],"student_count_band":"500-2000","departments":"Engineering","contact_name":"Fictional Applicant","contact_role":"TPO","contact_email":"tpo@fdu.example.test","contact_phone":"+91 1234567890","message":"Synthetic application","consent":true}'::jsonb)->>'reference'),'^AH-[A-Z0-9]{6}$','university application returns the frozen reference shape');
select is((select u.status from public.universities u join public.applications a on a.subject_id=u.id where a.reference=(public.lookup_submit_application_idempotency('af410000-0000-4000-8000-000000000010',repeat('a',64))->>'reference')),'pending','university application creates a pending subject');
select is((select a.status from public.applications a where a.reference=(public.lookup_submit_application_idempotency('af410000-0000-4000-8000-000000000010',repeat('a',64))->>'reference')),'received'::public.application_status,'application row is received');
select ok(exists(select 1 from public.notifications n where n.user_id='af410000-0000-4000-8000-000000000001' and n.kind='application_received' and n.payload->>'reference'=(public.lookup_submit_application_idempotency('af410000-0000-4000-8000-000000000010',repeat('a',64))->>'reference')),'admin receives a safe application notification');
select ok(exists(select 1 from public.audit_log l where l.action='application_received' and l.metadata->>'reference'=(public.lookup_submit_application_idempotency('af410000-0000-4000-8000-000000000010',repeat('a',64))->>'reference')),'application receipt is audit logged');
select ok(not exists(select 1 from public.applications a where a.reference=(public.lookup_submit_application_idempotency('af410000-0000-4000-8000-000000000010',repeat('a',64))->>'reference') and (a.payload ? 'hp' or a.payload ? 'captcha_token')),'honeypot and captcha values are never persisted');
select is((select public.submit_application('af410000-0000-4000-8000-000000000010',repeat('a',64),
'{"type":"university","institution_name":"Fictional Delta University","short_name":"FDU","kind":"university","tier":"tier2","city":"Jaipur","state":"Rajasthan","email_domains":["fdu.example.test"],"student_count_band":"500-2000","departments":"Engineering","contact_name":"Fictional Applicant","contact_role":"TPO","contact_email":"tpo@fdu.example.test","contact_phone":"+91 1234567890","message":"Synthetic application","consent":true}'::jsonb)->>'reference'),(public.lookup_submit_application_idempotency('af410000-0000-4000-8000-000000000010',repeat('a',64))->>'reference'),'same key/body replays the same receipt');
select throws_ok($$select public.submit_application('af410000-0000-4000-8000-000000000010',repeat('b',64),'{"type":"university","institution_name":"Different Synthetic University","kind":"university","tier":"tier1","city":"Jaipur","state":"Rajasthan","student_count_band":"<500","contact_name":"Fictional Contact","contact_role":"TPO","contact_email":"tpo@different.example.test","consent":true}'::jsonb)$$,'23505',null,'same key with different body is rejected');
select matches((public.submit_application('af410000-0000-4000-8000-000000000011',repeat('c',64),
'{"type":"organization","org_name":"Fictional Systems LLC","org_kind":"corporate","size_band":"11-50","website":"https://fictional.example.test/","hiring_focus":["web_frontend","data"],"contact_name":"Fictional Recruiter","contact_role":"Recruiter","work_email":"talent@fictional.example.test","message":"Synthetic hiring application","consent":true}'::jsonb)->>'reference'),'^AH-[A-Z0-9]{6}$','organization application returns a receipt');
select is((select o.status||':'||o.subscription_status from public.organizations o join public.applications a on a.subject_id=o.id where a.reference=(public.lookup_submit_application_idempotency('af410000-0000-4000-8000-000000000011',repeat('c',64))->>'reference')),'pending:inactive','organization is pending and has no active subscription');
reset role;
select ok(not exists(select 1 from auth.users where email in ('tpo@fdu.example.test','talent@fictional.example.test')),'submit application never creates an Auth login');
select * from finish();
rollback;
