-- Add the frozen university lifecycle labels while retaining `student` for backward-compatible internal rows.
-- Do not use the new enum values within this migration transaction; they are available to later migrations/requests.
alter type public.life_status add value if not exists 'incoming' before 'student';
alter type public.life_status add value if not exists 'enrolled' before 'student';
