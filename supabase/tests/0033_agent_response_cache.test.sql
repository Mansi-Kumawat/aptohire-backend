begin;
select plan(13);
select has_table('private','agent_response_cache','short-lived cache table exists');
select ok((select relrowsecurity from pg_class where oid='private.agent_response_cache'::regclass),'cache table has RLS enabled');
select has_function('public','read_agent_response_cache',array['text','text','text'],'read RPC exists');
select has_function('public','store_agent_response_cache',array['text','text','text','jsonb','text','text'],'store RPC exists');
select ok(has_function_privilege('service_role','public.read_agent_response_cache(text,text,text)','execute'),'service role can read cache');
select ok(has_function_privilege('service_role','public.store_agent_response_cache(text,text,text,jsonb,text,text)','execute'),'service role can write cache');
select ok(not has_table_privilege('authenticated','private.agent_response_cache','select'),'authenticated cannot read raw cache entries');
select ok(not has_function_privilege('authenticated','public.store_agent_response_cache(text,text,text,jsonb,text,text)','execute'),'authenticated cannot write cache entries');
select lives_ok($$select public.store_agent_response_cache('jd_extract',repeat('a',64),'jd-extract@1','{"skills":[]}'::jsonb,'gemini','synthetic-fast-model')$$,'service cache writer accepts validated synthetic output');
select is((select r.output->>'skills' from public.read_agent_response_cache('jd_extract',repeat('a',64),'jd-extract@1') r),'[]','cache reader returns JSON output');
insert into private.agent_response_cache(kind,input_hash,prompt_version,output,provider,model,created_at,expires_at)
values('jd_extract',repeat('b',64),'jd-extract@1','{"skills":[]}'::jsonb,'gemini','synthetic-fast-model',now()-interval '2 days',now()-interval '1 day');
select is((select count(*)::int from public.read_agent_response_cache('jd_extract',repeat('b',64),'jd-extract@1')),0,'expired cache entries are not returned');
select is((select count(*)::int from information_schema.columns where table_schema='private' and table_name='agent_response_cache' and column_name in ('raw_prompt','prompt_text','description')),0,'raw prompt text is never stored in cache');
select ok(pg_get_functiondef('public.store_agent_response_cache(text,text,text,jsonb,text,text)'::regprocedure) ilike '%65536%','cache output has a bounded serialized size');
select * from finish();
rollback;
