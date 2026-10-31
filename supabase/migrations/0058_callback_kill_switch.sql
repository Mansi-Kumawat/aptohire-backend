-- Make AI_KILL_SWITCH authoritative even for direct service-role RPC invocation.
alter function public.complete_agent_run(uuid,jsonb,text[]) rename to complete_agent_run_unchecked;
alter function public.complete_agent_run_unchecked(uuid,jsonb,text[]) set schema private;
revoke all on function private.complete_agent_run_unchecked(uuid,jsonb,text[]) from public,anon,authenticated,service_role;

create function public.complete_agent_run(p_run_id uuid,p_output jsonb,p_evidence_refs text[])
returns table(audit_id uuid,status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_enabled boolean;
begin
  select coalesce((c.value#>>'{}')::boolean,true)
    into v_enabled from public.app_config c where c.key='AI_KILL_SWITCH';
  if v_enabled is distinct from false then
    raise exception using errcode='55000',message='agent processing is paused';
  end if;
  return query select result.audit_id,result.status
    from private.complete_agent_run_unchecked(p_run_id,p_output,p_evidence_refs) as result;
end;
$$;
revoke all on function public.complete_agent_run(uuid,jsonb,text[]) from public,anon,authenticated;
grant execute on function public.complete_agent_run(uuid,jsonb,text[]) to service_role;
comment on function public.complete_agent_run(uuid,jsonb,text[]) is 'Service-only callback wrapper; fails closed on AI_KILL_SWITCH before calling the audited finalizer.';
