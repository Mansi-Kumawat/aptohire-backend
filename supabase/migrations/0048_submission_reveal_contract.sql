-- Persist the optional project fields required by the frozen reveal-student contract.
alter table public.submissions add column if not exists description text;
alter table public.submissions add column if not exists live_url text;
alter table public.submissions add column if not exists github_url text;
alter table public.submissions add column if not exists document_paths text[] not null default '{}';

revoke insert on public.submissions from authenticated;
grant insert (student_id,template_id,title,status,claimed_skill_ids,video_path,video_url,video_seconds,video_bytes,originality_answers,description,live_url,github_url,document_paths) on public.submissions to authenticated;
revoke update(description,live_url,github_url,document_paths) on public.submissions from authenticated;
grant update (description,live_url,github_url,document_paths) on public.submissions to authenticated;

create or replace function private.validate_submission_reveal_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_path text;
begin
  if new.description is not null and length(new.description)>4000 then
    raise exception using errcode='22023', message='project description is too long';
  end if;
  if new.live_url is not null and (length(new.live_url)>2000 or new.live_url !~ '^https://[^[:space:]]+$') then
    raise exception using errcode='22023', message='live_url must be an https URL';
  end if;
  if new.github_url is not null and (length(new.github_url)>2000 or new.github_url !~ '^https://(www\.)?github\.com/[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)?/?$') then
    raise exception using errcode='22023', message='github_url must point to a GitHub profile or repository';
  end if;
  if coalesce(cardinality(new.document_paths),0)>10 then
    raise exception using errcode='22023', message='at most 10 document paths are allowed';
  end if;
  if exists(select 1 from unnest(coalesce(new.document_paths,'{}'::text[])) as d(path)
            where d.path !~ ('^'||new.student_id::text||'/'||new.id::text||'/[A-Za-z0-9_-][A-Za-z0-9._-]{0,119}$')) then
    raise exception using errcode='22023', message='document paths must belong to this student and submission';
  end if;
  foreach v_path in array coalesce(new.document_paths,'{}'::text[]) loop
    if v_path is null then raise exception using errcode='22023', message='document path cannot be null'; end if;
  end loop;
  return new;
end;
$$;
revoke all on function private.validate_submission_reveal_fields() from public,anon,authenticated;
create trigger validate_submission_reveal_fields
before insert or update of description,live_url,github_url,document_paths,student_id on public.submissions
for each row execute function private.validate_submission_reveal_fields();
comment on column public.submissions.document_paths is 'Student-owned documents/{student_id}/{submission_id}/{filename} paths; signed URLs are issued only during a valid projects-scope reveal.';
