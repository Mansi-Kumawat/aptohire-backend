-- Jobs need a server-managed embedding for the secondary blind vector rerank.
-- Existing consumers and job columns remain unchanged; the new column is nullable
-- until a trusted embedding provider populates it.
alter table public.jobs add column if not exists embedding extensions.vector(768);
create index if not exists jobs_embedding_hnsw on public.jobs
using hnsw (embedding extensions.vector_cosine_ops) where embedding is not null;
comment on column public.jobs.embedding is 'Server-managed vector for the blind match pipeline; never accepted from organization clients.';
