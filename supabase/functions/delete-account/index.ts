// Supabase Edge Function: "delete-account"
// -----------------------------------------------------------------------------
// Giris yapmis kullanicinin hesabini KALICI olarak siler. auth.users satiri
// silinince metrics / entries / entry_tags / daily_scores tablolarindaki
// veriler "on delete cascade" ile otomatik temizlenir (bkz. schema.sql).
//
// Google Play politikasi: hesap olusturmaya izin veren uygulamalar, uygulama
// icinden hesap silme imkani da sunmak zorundadir. Bu fonksiyon onu saglar.
//
// Kurulum (terminalden, bir kez):
//   npx supabase functions deploy delete-account
// (SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY fonksiyona Supabase tarafindan
//  otomatik saglanir; ek secret ayarlamak GEREKMEZ.)
// -----------------------------------------------------------------------------

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  // Tarayici on-istegi (CORS)
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // config.toml'daki verify_jwt=true sayesinde buraya yalnizca gecerli
    // token'la gelinir; yine de token'dan kullanicinin kimligini dogrulariz
    // ki herkes SADECE KENDI hesabini silebilsin.
    const token = (req.headers.get("Authorization") ?? "")
      .replace("Bearer ", "");

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const { data: userData, error: userError } = await admin.auth.getUser(
      token,
    );
    if (userError || !userData?.user) {
      return json({ error: "Oturum doğrulanamadı. Tekrar giriş yap." }, 401);
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(
      userData.user.id,
    );
    if (deleteError) {
      return json({ error: "Hesap silinemedi. Lütfen tekrar dene." }, 500);
    }

    return json({ ok: true }, 200);
  } catch (e) {
    return json({ error: `Beklenmeyen hata: ${e}` }, 500);
  }
});

function json(obj: unknown, status: number): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}
