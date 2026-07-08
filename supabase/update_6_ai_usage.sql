-- ============================================================
-- Guncelleme 6: AI kullanim kotasi (kullanici basina gunluk limit)
-- ============================================================
-- Supabase panelinde SQL Editor > New query icine yapistirip calistir.
--
-- Amac: bir kullanicinin (ya da token'ini ele geciren birinin) Gemini
-- ucretsiz kotasini tuketmesini onlemek. Her kullanici icin gunluk istek
-- sayisi tutulur; ai-fill fonksiyonu her cagride bu sayaci artirir ve
-- limit asilirsa Gemini'yi hic cagirmadan hata doner.

create table if not exists public.ai_usage (
  user_id     uuid not null references auth.users(id) on delete cascade,
  usage_date  date not null default current_date,
  count       integer not null default 0,
  primary key (user_id, usage_date)
);

alter table public.ai_usage enable row level security;

-- Kullanici yalnizca kendi kullanim sayacini GOREBILIR (yazma RPC ile yapilir).
drop policy if exists "own_select" on public.ai_usage;
create policy "own_select" on public.ai_usage
  for select using (auth.uid() = user_id);

-- Atomik "kontrol et ve artir": bugunku sayaci 1 artirir ve yeni degerin
-- limiti asip asmadigini doner. security definer sayesinde RLS'i asarak
-- yalnizca giris yapmis kullanicinin KENDI satirini gunceller (auth.uid()).
create or replace function public.check_and_increment_ai_usage(p_limit int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  new_count int;
  uid uuid := auth.uid();
begin
  if uid is null then
    return false; -- oturum yoksa izin verme
  end if;

  insert into public.ai_usage (user_id, usage_date, count)
  values (uid, current_date, 1)
  on conflict (user_id, usage_date)
  do update set count = ai_usage.count + 1
  returning count into new_count;

  return new_count <= p_limit;
end;
$$;

-- Fonksiyonu yalnizca giris yapmis kullanicilar cagirabilsin.
revoke all on function public.check_and_increment_ai_usage(int) from public;
grant execute on function public.check_and_increment_ai_usage(int) to authenticated;
