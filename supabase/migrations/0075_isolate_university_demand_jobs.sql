-- University demand output must not count jobs from unapproved organizations.
create or replace view public.university_demand_v with (security_invoker=false) as
select sk.id,sk.name as skill_name,
       count(distinct j.id) filter(where j.status='open')::int as jobs_count,
       coalesce((select jsonb_object_agg(rc.reason,rc.total) from (
         select kv.key as reason,sum(kv.value::int) as total
         from public.demand_signals ds cross join lateral jsonb_each_text(ds.reason_counts) kv
         where ds.university_id=any(private.my_university_ids()) and sk.slug=any(ds.skill_slugs)
         group by kv.key) rc),'{}'::jsonb) as reasons,
       max(j.created_at) as last_posted_at
from public.skills sk
left join lateral (
  select distinct job.id,job.status,job.created_at
  from public.jobs job
  join public.organizations org on org.id=job.organization_id and org.status='approved'
  cross join lateral jsonb_array_elements(coalesce(job.required_skills,'[]'::jsonb)) as req(item)
  where job.status='open' and req.item->>'skill_id'=sk.id::text
) j on true
where private.my_university_ids() <> '{}'::uuid[] or private.is_admin()
group by sk.id,sk.name;
comment on view public.university_demand_v is
  'University-scoped demand reasons; open-job counts include only approved organizations; never returns student identifiers.';
