-- Universities can manage placement outcomes for unclaimed roster entries without fabricating a student row.
create or replace function private.set_placement_actor() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 new.updated_by := auth.uid();
 new.updated_at := now();
 return new;
end $$;
revoke all on function private.set_placement_actor() from public,anon,authenticated;
create trigger placements_set_actor before insert or update on public.placements for each row execute function private.set_placement_actor();

revoke insert,update on public.placements from authenticated;
grant insert (university_id,roster_entry_id,status,organization_name_text,role_text,source) on public.placements to authenticated;
grant update (status,organization_name_text,role_text,source) on public.placements to authenticated;
create policy placement_unclaimed_university_insert on public.placements for insert to authenticated with check(
 source='university' and student_id is null and roster_entry_id is not null
 and university_id=any(private.my_university_ids())
 and exists(select 1 from public.roster_entries r where r.id=roster_entry_id and r.university_id=placements.university_id and r.student_id is null)
);
create policy placement_unclaimed_university_update on public.placements for update to authenticated using(
 source='university' and student_id is null and roster_entry_id is not null and university_id=any(private.my_university_ids())
 and exists(select 1 from public.roster_entries r where r.id=roster_entry_id and r.university_id=placements.university_id and r.student_id is null)
) with check(
 source='university' and student_id is null and roster_entry_id is not null and university_id=any(private.my_university_ids())
 and exists(select 1 from public.roster_entries r where r.id=roster_entry_id and r.university_id=placements.university_id and r.student_id is null)
);
