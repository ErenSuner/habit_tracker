-- ============================================================
-- Guncelleme 3: metriklere kategori (gruplama icin)
-- ============================================================
-- Supabase > SQL Editor > New query icine yapistirip bir kez calistir.
-- ============================================================

alter table public.metrics
  add column if not exists category text;
