-- ============================================================
-- Guncelleme 5: gunluk ekran suresi kayitlari
-- ============================================================
-- Supabase panelinde SQL Editor > New query icine yapistirip calistir.
--
-- Android gunluk kullanim detayini cihazda yalnizca ~1 hafta tutar;
-- 7/30/60 gunluk ortalamalari gosterebilmek icin uygulama her acilista
-- okudugu degeri buraya yazar.

create table if not exists public.screen_times (
  user_id     uuid not null references auth.users(id) on delete cascade,
  entry_date  date not null,
  minutes     integer not null default 0,
  updated_at  timestamptz not null default now(),
  primary key (user_id, entry_date)
);

alter table public.screen_times enable row level security;

drop policy if exists "own_select" on public.screen_times;
drop policy if exists "own_insert" on public.screen_times;
drop policy if exists "own_update" on public.screen_times;
drop policy if exists "own_delete" on public.screen_times;

create policy "own_select" on public.screen_times for select using (auth.uid() = user_id);
create policy "own_insert" on public.screen_times for insert with check (auth.uid() = user_id);
create policy "own_update" on public.screen_times for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_delete" on public.screen_times for delete using (auth.uid() = user_id);
