begin;
select plan(3);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values ('a0850000-0000-4000-8000-000000000001','authenticated','authenticated','notification-kinds@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());

select lives_ok($$insert into public.notifications(user_id,kind,payload)
select 'a0850000-0000-4000-8000-000000000001'::uuid,k,'{}'::jsonb
from unnest(array[
 'audit_ready','review_needed','review_decided','appeal_update','access_request','access_expiring','affiliation_proposal','feedback_received','source_proposals',
 'application_decided','roster_matched','demand_alert','student_registered','access_accepted','access_declined','access_withdrawn','new_match','subscription_changed',
 'application_received','ticket_opened','run_failed'
]::text[]) as allowed(k)$$,'all frozen notification kinds are accepted by the database contract');

select is(
  (select array_agg(kind order by kind) from public.notifications where user_id='a0850000-0000-4000-8000-000000000001'),
  (select array_agg(k order by k) from unnest(array[
   'audit_ready','review_needed','review_decided','appeal_update','access_request','access_expiring','affiliation_proposal','feedback_received','source_proposals',
   'application_decided','roster_matched','demand_alert','student_registered','access_accepted','access_declined','access_withdrawn','new_match','subscription_changed',
   'application_received','ticket_opened','run_failed'
  ]::text[]) as expected(k)),
  'stored notification kinds exactly match the frozen 21-kind portal contract'
);

select throws_ok($$insert into public.notifications(user_id,kind,payload)
values('a0850000-0000-4000-8000-000000000001','unknown_notification_kind','{}'::jsonb)$$,
'23514',null,'unknown notification kinds are rejected');

select * from finish();
rollback;
