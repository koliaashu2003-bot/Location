-- Family Safety — Supabase schema
-- Run this in your Supabase project: SQL Editor → New query → paste → Run.
--
-- Row Level Security ties every row to the signed-in family account
-- (auth.uid()), so your data is private and readable only after signing in
-- with the shared family email/password.

-- ---------- locations ----------
create table if not exists public.locations (
  id          bigint generated always as identity primary key,
  user_id     uuid not null default auth.uid(),
  device_id   text not null,
  device_name text,
  latitude    double precision,
  longitude   double precision,
  battery     int,
  created_at  timestamptz not null default now()
);

alter table public.locations enable row level security;

create policy "locations_select_own" on public.locations
  for select using (auth.uid() = user_id);
create policy "locations_insert_own" on public.locations
  for insert with check (auth.uid() = user_id);
create policy "locations_delete_own" on public.locations
  for delete using (auth.uid() = user_id);

create index if not exists locations_device_time_idx
  on public.locations (device_id, created_at desc);

-- ---------- screen_time (one row per device per day) ----------
create table if not exists public.screen_time (
  id            bigint generated always as identity primary key,
  user_id       uuid not null default auth.uid(),
  device_id     text not null,
  device_name   text,
  date          date not null,
  total_minutes int,
  apps          jsonb,
  created_at    timestamptz not null default now()
);

alter table public.screen_time enable row level security;

create policy "screen_time_select_own" on public.screen_time
  for select using (auth.uid() = user_id);
create policy "screen_time_insert_own" on public.screen_time
  for insert with check (auth.uid() = user_id);
create policy "screen_time_delete_own" on public.screen_time
  for delete using (auth.uid() = user_id);

create index if not exists screen_time_device_date_idx
  on public.screen_time (device_id, date desc);

-- Retention: the app deletes rows older than 3 days on each write, so no
-- scheduled job is required. If you prefer server-side cleanup and have the
-- pg_cron extension enabled, you could instead schedule daily deletes.
