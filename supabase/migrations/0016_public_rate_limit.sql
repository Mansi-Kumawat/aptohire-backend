-- Atomically increment a hashed bucket. The Edge Function HMACs identifiers before calling this RPC.
create or replace function public.consume_rate_limit(p_bucket text,p_key_hash text,p_max int,p_window_seconds int)
returns table(allowed boolean, retry_after int)
language plpgsql security definer set search_path = '' as $$
declare v_start timestamptz; v_count int;
begin
 if p_bucket is null or length(p_bucket)>80 or p_key_hash !~ '^[a-f0-9]{64}$' or p_max<1 or p_window_seconds<1 then
  raise exception 'invalid rate limit arguments';
 end if;
 v_start := to_timestamp(floor(extract(epoch from now())/p_window_seconds)*p_window_seconds);
 insert into private.rate_limits(bucket,key_hash,window_start,count) values(p_bucket,p_key_hash,v_start,1)
 on conflict(bucket,key_hash,window_start) do update set count=private.rate_limits.count+1
 returning count into v_count;
 return query select v_count<=p_max, greatest(1,ceil(extract(epoch from(v_start+make_interval(secs=>p_window_seconds)-now())))::int);
end $$;
revoke all on function public.consume_rate_limit(text,text,int,int) from public,anon,authenticated;
grant execute on function public.consume_rate_limit(text,text,int,int) to service_role;
