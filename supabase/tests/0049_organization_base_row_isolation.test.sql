begin;
select plan(17);

insert into auth.users(id,aud,role,email,email_confirmed_at,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('a0490000-0000-4000-8000-000000000001','authenticated','authenticated','org-a-rls@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0490000-0000-4000-8000-000000000002','authenticated','authenticated','org-b-rls@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0490000-0000-4000-8000-000000000003','authenticated','authenticated','student-org-directory@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now()),
 ('a0490000-0000-4000-8000-000000000004','authenticated','authenticated','admin-org-directory@demo.aptohire.test',now(),extensions.crypt('synthetic-only',extensions.gen_salt('bf')),'{}','{}',now(),now());
insert into public.profiles(id,role) values
 ('a0490000-0000-4000-8000-000000000001','organization'),
 ('a0490000-0000-4000-8000-000000000002','organization'),
 ('a0490000-0000-4000-8000-000000000003','student'),
 ('a0490000-0000-4000-8000-000000000004','admin');
insert into public.organizations(id,name,kind,size,website,status,verified_at,subscription_status)
values
 ('a0490000-0000-4000-8000-000000000011','Synthetic Organization A','corporate','small','https://orga.example.test','approved',now(),'active'),
 ('a0490000-0000-4000-8000-000000000012','Synthetic Organization B','startup','small','https://orgb.example.test','approved',now(),'active');
insert into public.organization_members(organization_id,user_id,member_role) values
 ('a0490000-0000-4000-8000-000000000011','a0490000-0000-4000-8000-000000000001','recruiter'),
 ('a0490000-0000-4000-8000-000000000012','a0490000-0000-4000-8000-000000000002','recruiter');

select is(
  (select count(*)::int from pg_policies where schemaname='public' and 'authenticated'::name=any(roles)
    and ((tablename='organizations' and policyname='organizations_member_read' and cmd='SELECT')
      or (tablename='organization_members' and policyname='organization_member_read' and cmd='SELECT'))),
  2,
  'organization and membership behavior below maps to both active named read policies'
);
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='organizations' and policyname='organizations_member_read'),'member-only base-table policy exists');
select ok(not exists(select 1 from pg_policies where schemaname='public' and tablename='organizations' and policyname='organization_public_or_member'),'broad approved-row policy is removed');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a0490000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.organizations where id='a0490000-0000-4000-8000-000000000011'),1,'organization A member can read its own base row');
select is((select count(*)::int from public.organizations where id='a0490000-0000-4000-8000-000000000012'),0,'organization A member cannot read organization B base row');
select is((select count(*)::int from public.public_organizations where id='a0490000-0000-4000-8000-000000000012'),1,'approved public directory still exposes organization B to organization A');
select is((select count(*)::int from public.organization_members where organization_id='a0490000-0000-4000-8000-000000000011'),1,'organization A member can read its own membership row');
select is((select count(*)::int from public.organization_members where organization_id='a0490000-0000-4000-8000-000000000012'),0,'organization A member cannot read organization B membership row');

select set_config('request.jwt.claims','{"sub":"a0490000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.organizations where id='a0490000-0000-4000-8000-000000000012'),1,'organization B member can read its own base row');
select is((select count(*)::int from public.organizations where id='a0490000-0000-4000-8000-000000000011'),0,'organization B member cannot read organization A base row');
select is((select count(*)::int from public.organization_members where organization_id='a0490000-0000-4000-8000-000000000012'),1,'organization B member can read its own membership row');
select is((select count(*)::int from public.organization_members where organization_id='a0490000-0000-4000-8000-000000000011'),0,'organization B member cannot read organization A membership row');

select set_config('request.jwt.claims','{"sub":"a0490000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',true);
select is((select count(*)::int from public.public_organizations where id in ('a0490000-0000-4000-8000-000000000011','a0490000-0000-4000-8000-000000000012')),2,'student can browse both approved organizations through the explicit public view');
select is((select count(*)::int from public.organizations where id in ('a0490000-0000-4000-8000-000000000011','a0490000-0000-4000-8000-000000000012')),0,'student cannot query organization base rows directly');
select is((select count(*)::int from public.organization_members where organization_id in ('a0490000-0000-4000-8000-000000000011','a0490000-0000-4000-8000-000000000012')),0,'student cannot read organization membership rows');

select set_config('request.jwt.claims','{"sub":"a0490000-0000-4000-8000-000000000004","role":"authenticated","aal":"aal2"}',true);
select is((select count(*)::int from public.organizations where id in ('a0490000-0000-4000-8000-000000000011','a0490000-0000-4000-8000-000000000012')),2,'aal2 admin can read both organization base rows');
select is((select count(*)::int from public.organization_members where organization_id in ('a0490000-0000-4000-8000-000000000011','a0490000-0000-4000-8000-000000000012')),2,'aal2 admin can read both organization membership rows');

select * from finish();
rollback;
