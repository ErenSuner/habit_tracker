-- ============================================================
-- Guncelleme 2: boolean metriklere opsiyonel sayisal deger
-- ============================================================
-- schema.sql'i daha once calistirdiysan, bu kucuk eklemeyi de
-- Supabase > SQL Editor > New query icinde bir kez calistir.
-- ============================================================

alter table public.metrics
  add column if not exists bool_has_value boolean not null default false;
