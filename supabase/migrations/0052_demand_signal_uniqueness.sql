-- One current aggregate per job/university; discard duplicate stale aggregates before enforcing uniqueness.
delete from public.demand_signals older
using public.demand_signals newer
where older.job_id=newer.job_id
  and older.university_id=newer.university_id
  and older.university_id is not null
  and older.ctid>newer.ctid;

create unique index if not exists demand_signals_job_university_uq
  on public.demand_signals(job_id,university_id)
  where university_id is not null;
