-- Membrane Watch: admin moderation of video proof clips
--   hidden   admin and team_management still see the clip (marked Hidden); vendors don't
--   deleted  nobody sees the clip in the portal
-- A clip with no row here is visible to everyone. The clip list itself lives in video-proof.js.
--
-- Run once in Supabase Dashboard -> SQL Editor, after 001_profiles.sql. Safe to re-run.

create table if not exists public.video_moderation (
  clip_url        text primary key,
  machine_barcode text not null,
  status          text not null check (status in ('hidden', 'deleted')),
  updated_by      uuid default auth.uid() references auth.users (id) on delete set null,
  updated_at      timestamptz not null default now()
);

drop trigger if exists video_moderation_touch_updated_at on public.video_moderation;
create trigger video_moderation_touch_updated_at
  before update on public.video_moderation
  for each row execute function public.touch_updated_at();

-- ---------- Row Level Security ----------
alter table public.video_moderation enable row level security;

-- Every signed-in user reads it, so vendors' pages know which clips to leave out
drop policy if exists "video_moderation: signed-in read" on public.video_moderation;
create policy "video_moderation: signed-in read" on public.video_moderation
  for select using (auth.uid() is not null);

drop policy if exists "video_moderation: admin write" on public.video_moderation;
create policy "video_moderation: admin write" on public.video_moderation
  for all using (public.is_admin()) with check (public.is_admin());
