do $$ begin
 alter publication supabase_realtime add table public.submissions;
 alter publication supabase_realtime add table public.agent_runs;
 alter publication supabase_realtime add table public.notifications;
 alter publication supabase_realtime add table public.access_requests;
exception when duplicate_object then null;
end $$;
