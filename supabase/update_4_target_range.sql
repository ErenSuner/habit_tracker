-- ============================================================
-- Guncelleme 4: sayisal metriklere "aralik" hedefi
-- ============================================================
-- Supabase panelinde SQL Editor > New query icine yapistirip calistir.
--
-- Yeni hedef yonu 'range': deger [target_min, target] araligindaysa tam
-- puan; disina ciktikca verim duser. Ornek: uyku 7-9 saat.
--   target_min -> araligin ALT siniri
--   target     -> araligin UST siniri (mevcut kolon yeniden kullanilir)

alter table public.metrics
  add column if not exists target_min numeric;

alter table public.metrics
  drop constraint if exists metrics_target_direction_check;

alter table public.metrics
  add constraint metrics_target_direction_check
  check (target_direction in ('up', 'down', 'range'));
