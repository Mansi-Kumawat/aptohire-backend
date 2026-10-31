-- Normalize legacy fictional university lifecycle and program values to the frozen API vocabulary.
-- Legacy `student` enum value remains accepted for old records and direct internal workflows.
update public.roster_entries set status='enrolled' where status='student';
update public.affiliations set status='enrolled' where status='student';
update public.affiliation_proposals set status='enrolled' where status='student';

alter table public.roster_entries alter column status set default 'enrolled';
alter table public.affiliations alter column status set default 'enrolled';

update public.roster_entries set program_level=case
  when lower(pg_catalog.btrim(program_level)) in ('ug','undergraduate','undergrad','bachelor','bachelors','bachelor''s','b.sc','bsc','b.tech','btech') then 'ug'
  when lower(pg_catalog.btrim(program_level)) in ('pg','postgraduate','post-graduate','graduate','master','masters','master''s','m.sc','msc','m.tech','mtech','phd','doctorate') then 'pg'
  else program_level end
where program_level is not null;
update public.affiliations set program_level=case
  when lower(pg_catalog.btrim(program_level)) in ('ug','undergraduate','undergrad','bachelor','bachelors','bachelor''s','b.sc','bsc','b.tech','btech') then 'ug'
  when lower(pg_catalog.btrim(program_level)) in ('pg','postgraduate','post-graduate','graduate','master','masters','master''s','m.sc','msc','m.tech','mtech','phd','doctorate') then 'pg'
  else program_level end
where program_level is not null;
update public.affiliation_proposals set program_level=case
  when lower(pg_catalog.btrim(program_level)) in ('ug','undergraduate','undergrad','bachelor','bachelors','bachelor''s','b.sc','bsc','b.tech','btech') then 'ug'
  when lower(pg_catalog.btrim(program_level)) in ('pg','postgraduate','post-graduate','graduate','master','masters','master''s','m.sc','msc','m.tech','mtech','phd','doctorate') then 'pg'
  else program_level end
where program_level is not null;
