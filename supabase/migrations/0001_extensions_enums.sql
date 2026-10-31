create extension if not exists pgcrypto with schema extensions;
create extension if not exists citext with schema extensions;
create extension if not exists vector with schema extensions;
create extension if not exists pg_cron with schema extensions;
create type public.life_status as enum ('student','alumni','dropout');
create type public.affiliation_verification as enum ('roster','student_id','unverified');
create type public.application_status as enum ('received','approved','rejected');
