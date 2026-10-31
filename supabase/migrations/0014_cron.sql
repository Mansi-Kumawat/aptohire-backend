-- Keep schedules conservative; function-driven HTTP cron jobs are intentionally deferred until
-- authenticated internal Edge Function dispatch is implemented.
select cron.schedule('aptohire-rate-limit-purge','15 3 * * *',$$delete from private.rate_limits where window_start < now() - interval '2 days'$$);
select cron.schedule('aptohire-idempotency-purge','25 3 * * *',$$delete from private.idempotency_keys where created_at < now() - interval '24 hours'$$);
select cron.schedule('aptohire-draft-retention','45 3 * * *',$$delete from public.submissions where status='draft' and created_at < now() - interval '30 days'$$);
