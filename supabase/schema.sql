-- ============================================================
-- Habit Tracker - Supabase veritabani semasi
-- ============================================================
-- Bu dosyayi Supabase panelinde: SQL Editor > New query
-- icine yapistirip "Run" ile bir kez calistir.
-- Her kullanici yalnizca kendi verisini gorur (RLS politikalari ile).
-- ============================================================

-- ----------------------------------------------------------------
-- 1) metrics : takip edilen kalemlerin TANIMI
--    Ornek: "Kalori" (numeric), "Spor yaptim" (boolean),
--           "Arastirilan konular" (tag), "Gunun notu" (text)
-- ----------------------------------------------------------------
create table if not exists public.metrics (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  -- tip: 'numeric' | 'boolean' | 'tag' | 'text'
  type        text not null check (type in ('numeric','boolean','tag','text')),
  unit        text,                       -- ornek: 'kcal', 'sayfa', 'dk'
  target      numeric,                    -- sayisal hedef; range'de UST sinir
  target_min  numeric,                    -- yalnizca range yonunde: ALT sinir
  -- hedef yonu: 'up' = cok olmasi iyi (adim), 'down' = az olmasi iyi (kalori),
  -- 'range' = [target_min, target] araliginda olmasi iyi (uyku saati)
  target_direction text not null default 'up' check (target_direction in ('up','down','range')),
  weight      numeric not null default 1, -- verim puanindaki agirligi
  -- boolean metriklerde "iyi" durum hangisi? true = "evet iyi", false = "hayir iyi"
  good_value  boolean not null default true,
  -- boolean metrikte "Evet" secilince ayrica sayisal deger de istensin mi?
  bool_has_value boolean not null default false,
  active      boolean not null default true,
  sort_order  int not null default 0,
  icon        text,                       -- opsiyonel ikon adi
  created_at  timestamptz not null default now()
);

-- ----------------------------------------------------------------
-- 2) entries : sayisal / boolean / metin tipli GUNLUK kayitlar
--    Her metrik icin her gun en fazla 1 satir.
-- ----------------------------------------------------------------
create table if not exists public.entries (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  metric_id   uuid not null references public.metrics(id) on delete cascade,
  entry_date  date not null,
  num_value   numeric,
  bool_value  boolean,
  text_value  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, metric_id, entry_date)
);

-- ----------------------------------------------------------------
-- 3) entry_tags : etiket (tag) tipli metrikler icin GUNLUK kayitlar
--    Bir gunde ayni metrige birden fazla etiket girilebilir.
--    Ornek: 19 Haziran > "Arastirilan konular" > [liberalizm, anarsizm]
-- ----------------------------------------------------------------
create table if not exists public.entry_tags (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  metric_id   uuid not null references public.metrics(id) on delete cascade,
  entry_date  date not null,
  tag         text not null,
  created_at  timestamptz not null default now(),
  unique (user_id, metric_id, entry_date, tag)
);

-- ----------------------------------------------------------------
-- 4) daily_scores : her gun icin hesaplanan % verim (onbellek)
--    Uygulama gunu kaydederken bu degeri gunceller.
-- ----------------------------------------------------------------
create table if not exists public.daily_scores (
  user_id     uuid not null references auth.users(id) on delete cascade,
  entry_date  date not null,
  score       numeric not null default 0, -- 0..100
  updated_at  timestamptz not null default now(),
  primary key (user_id, entry_date)
);

-- ----------------------------------------------------------------
-- 5) screen_times : gunluk ekran suresi (dakika)
--    Telefondan okunur; Android gecmisi kisa tuttugu icin burada saklanir.
-- ----------------------------------------------------------------
create table if not exists public.screen_times (
  user_id     uuid not null references auth.users(id) on delete cascade,
  entry_date  date not null,
  minutes     integer not null default 0,
  updated_at  timestamptz not null default now(),
  primary key (user_id, entry_date)
);

-- Hizli sorgu icin indeksler
create index if not exists idx_entries_user_date on public.entries(user_id, entry_date);
create index if not exists idx_entry_tags_user_date on public.entry_tags(user_id, entry_date);

-- ============================================================
-- RLS (Row Level Security): herkes yalnizca kendi satirlarini gorur
-- ============================================================
alter table public.metrics       enable row level security;
alter table public.entries       enable row level security;
alter table public.entry_tags    enable row level security;
alter table public.daily_scores  enable row level security;
alter table public.screen_times  enable row level security;

-- Her tablo icin: kullanici sadece kendi user_id'sine ait satirlara erisebilir.
do $$
declare t text;
begin
  foreach t in array array['metrics','entries','entry_tags','daily_scores','screen_times'] loop
    execute format('drop policy if exists "own_select" on public.%I;', t);
    execute format('drop policy if exists "own_insert" on public.%I;', t);
    execute format('drop policy if exists "own_update" on public.%I;', t);
    execute format('drop policy if exists "own_delete" on public.%I;', t);

    execute format('create policy "own_select" on public.%I for select using (auth.uid() = user_id);', t);
    execute format('create policy "own_insert" on public.%I for insert with check (auth.uid() = user_id);', t);
    execute format('create policy "own_update" on public.%I for update using (auth.uid() = user_id) with check (auth.uid() = user_id);', t);
    execute format('create policy "own_delete" on public.%I for delete using (auth.uid() = user_id);', t);
  end loop;
end $$;
