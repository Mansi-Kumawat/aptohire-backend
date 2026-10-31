create or replace function public.update_my_visibility(p_visibility jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare allowed text[] := array['skills','levels','scores','name','university']; shared text[];
begin
 if auth.uid() is null then raise exception 'unauthenticated'; end if;
 if jsonb_typeof(p_visibility)<>'object' or (p_visibility - array['public_verify','discoverable','university_files'])<>'{}'::jsonb then raise exception 'invalid visibility shape'; end if;
 if jsonb_typeof(p_visibility->'public_verify')<>'array' or jsonb_typeof(p_visibility->'discoverable')<>'boolean' or jsonb_typeof(p_visibility->'university_files')<>'boolean' then raise exception 'invalid visibility fields'; end if;
 select array_agg(x) into shared from jsonb_array_elements_text(p_visibility->'public_verify') e(x);
 if exists(select 1 from unnest(coalesce(shared,'{}'::text[])) x where not x=any(allowed)) then raise exception 'invalid shared field'; end if;
 if 'levels'=any(coalesce(shared,'{}'::text[])) and not 'skills'=any(shared) then raise exception 'levels requires skills'; end if;
 if 'scores'=any(coalesce(shared,'{}'::text[])) and not 'levels'=any(shared) then raise exception 'scores requires levels'; end if;
 update public.students set visibility=p_visibility, updated_at=now() where user_id=auth.uid();
 if not found then raise exception 'student not found'; end if;
 return p_visibility;
end $$;
revoke all on function public.update_my_visibility(jsonb) from public,anon,authenticated;
grant execute on function public.update_my_visibility(jsonb) to authenticated;
