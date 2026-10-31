begin;
select plan(5);
select has_column('public','jobs','embedding','jobs carries a nullable server-managed embedding');
select ok(exists(select 1 from pg_indexes where schemaname='public' and indexname='jobs_embedding_hnsw'),'jobs embedding has a vector search index');
select ok(not has_column_privilege('authenticated','public.jobs','embedding','update'),'organization clients cannot write job embeddings');
select has_column('public','match_results','structured_score','structured score remains available');
select has_column('public','match_results','vector_score','vector score remains available');
select * from finish();
rollback;
