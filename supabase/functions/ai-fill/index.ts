// Supabase Edge Function: "ai-fill"
// -----------------------------------------------------------------------------
// Kullanicinin serbest metnini ("bugun 1 saat kostum, 30 sayfa okudum...")
// alir, metrik listesiyle birlikte Gemini'ye gonderir ve yapilandirilmis
// giris onerileri dondurur. Gemini API anahtari SADECE burada (sunucuda)
// bulunur; uygulamaya gomulmez.
//
// Kurulum (terminalden, bir kez):
//   npx supabase secrets set GEMINI_API_KEY=...
//   npx supabase functions deploy ai-fill
//
// API anahtarini https://aistudio.google.com adresinden ucretsiz alabilirsin
// (ucretsiz katman bu kullanim icin yeterli).
// -----------------------------------------------------------------------------

import { createClient } from "npm:@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");

// Kotuye kullanima karsi sinirlar:
const DAILY_LIMIT = 40; // kullanici basina gunluk istek (Gemini ucretsiz: 500/gun toplam)
const MAX_MESSAGE_CHARS = 2000; // tek mesajin ust siniri
const MAX_HISTORY_TURNS = 10; // gecmisten en fazla son N tur gonderilir

// Kullanilacak model. Ucuz/hizli "flash-lite" sinifi bu gorev icin yeterli.
// 3.1 Flash Lite secildi cunku ucretsiz katmanda en yuksek limitlere sahip
// (gunluk 500 istek, dakikada 15) ve function calling destekler.
// Alternatifler: "gemini-2.5-flash-lite" (gunluk sadece 20), "gemini-2.5-flash".
const MODEL = "gemini-3.1-flash-lite";

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
    if (!GEMINI_API_KEY) {
      return json({ error: "Sunucuda GEMINI_API_KEY tanimli degil." }, 500);
    }

    const body = await req.json();
    // Girdi sinirlari: uzun mesaj/gecmis hem maliyeti hem kotayi sömürur.
    const message: string = (body.message ?? "").slice(0, MAX_MESSAGE_CHARS);
    const metrics: MetricInfo[] = body.metrics ?? [];
    const history: ChatTurn[] = (body.history ?? []).slice(-MAX_HISTORY_TURNS);

    if (!message.trim()) {
      return json({ error: "Mesaj bos." }, 400);
    }

    // Gunluk kota kontrolu: cagriyi yapan kullanicinin sayacini atomik olarak
    // artir; limiti astiysa Gemini'yi HIC cagirmadan don. Sayac tablosu/RPC
    // henuz kurulmadiysa (migration eksik) ozelligi bloklamamak icin izin
    // verilir (fail-open) — asil koruma tablo kurulunca devreye girer.
    const authHeader = req.headers.get("Authorization") ?? "";
    try {
      const supabase = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_ANON_KEY")!,
        { global: { headers: { Authorization: authHeader } } },
      );
      const { data: allowed, error: rpcError } = await supabase.rpc(
        "check_and_increment_ai_usage",
        { p_limit: DAILY_LIMIT },
      );
      if (!rpcError && allowed === false) {
        return json({
          error:
            `Günlük AI kullanım sınırına ulaştın (${DAILY_LIMIT} istek). ` +
            `Yarın tekrar deneyebilirsin.`,
        }, 429);
      }
    } catch (_) {
      // Kota kontrol edilemedi: ozelligi bloklama, devam et.
    }

    // Metrik listesini modele tanitan sistem komutu.
    const metricsText = metrics
      .map((m) => {
        const extra = [
          m.unit ? `birim: ${m.unit}` : null,
          m.target != null ? `hedef: ${m.target}` : null,
          m.type === "boolean" && m.bool_has_value
            ? `EVET secilince ayrica sayisal deger de istiyor (num_value)`
            : null,
        ]
          .filter(Boolean)
          .join(", ");
        return `- id=${m.id} | "${m.name}" | tip=${m.type}${
          extra ? ` (${extra})` : ""
        }`;
      })
      .join("\n");

    const system = `Sen bir kisisel takip uygulamasinin asistanisin. Kullanici gununu serbestce anlatir; sen anlatilanlari asagidaki metriklere gore yapilandirilmis girislere cevirirsin.

Kullanilabilir metrikler:
${metricsText}

Kurallar:
- SADECE kullanicinin gercekten bahsettigi metrikler icin giris olustur.
- Her giriste dogru metric_id'yi kullan.
- numeric metrikte num_value ver (sadece sayi). boolean metrikte bool_value (true/false). text metrikte text_value. tag metrikte tags dizisine etiketleri koy.
- Bir boolean metrik "EVET secilince ayrica sayisal deger de istiyor" diye isaretliyse ve kullanici o eylemi bir miktarla yaptiysa, HEM bool_value=true HEM num_value=<miktar> ver. Ornek: "bugun 3 defa X yaptim" -> o metrik icin bool_value=true, num_value=3.
- Emin olamadigin seyleri uydurmadan birak.
- "reply" alaninda kullaniciya kisa, samimi, Turkce bir ozet yaz (orn. "Sunlari isaretledim, onaylar misin?").`;

    // Modelin yapilandirilmis cevap vermesi icin tek bir fonksiyon tanimlariz
    // ve onu cagirmaya zorlariz (functionCallingConfig: ANY).
    const functionDeclaration = {
      name: "propose_day_entries",
      description:
        "Kullanicinin anlattiklarini takip uygulamasi girislerine cevir.",
      parameters: {
        type: "OBJECT",
        properties: {
          reply: {
            type: "STRING",
            description: "Kullaniciya gosterilecek kisa Turkce ozet/yanit.",
          },
          entries: {
            type: "ARRAY",
            items: {
              type: "OBJECT",
              properties: {
                metric_id: { type: "STRING" },
                metric_name: { type: "STRING" },
                type: {
                  type: "STRING",
                  enum: ["numeric", "boolean", "tag", "text"],
                },
                num_value: { type: "NUMBER", nullable: true },
                bool_value: { type: "BOOLEAN", nullable: true },
                text_value: { type: "STRING", nullable: true },
                tags: { type: "ARRAY", items: { type: "STRING" } },
              },
              required: ["metric_id", "type"],
            },
          },
        },
        required: ["reply", "entries"],
      },
    };

    // Gecmis + guncel mesaj (Gemini rolleri: "user" / "model").
    const contents = [
      ...history.map((t) => ({
        role: t.role === "assistant" ? "model" : "user",
        parts: [{ text: t.content }],
      })),
      { role: "user", parts: [{ text: message }] },
    ];

    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

    const geminiRes = await fetch(url, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-goog-api-key": GEMINI_API_KEY,
      },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents,
        tools: [{ functionDeclarations: [functionDeclaration] }],
        toolConfig: {
          functionCallingConfig: {
            mode: "ANY",
            allowedFunctionNames: ["propose_day_entries"],
          },
        },
        generationConfig: { maxOutputTokens: 2048, temperature: 0.2 },
      }),
    });

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      return json({ error: `Gemini API hatasi: ${errText}` }, 502);
    }

    const data = await geminiRes.json();
    // Zorunlu fonksiyon cagrisi nedeniyle cevap bir functionCall icerir.
    const parts = data?.candidates?.[0]?.content?.parts ?? [];
    const fnCall = parts.find(
      (p: { functionCall?: unknown }) => p.functionCall,
    )?.functionCall;

    if (!fnCall?.args) {
      return json({ error: "Model yapilandirilmis cevap dondurmedi." }, 502);
    }

    // fnCall.args = { reply, entries } (uygulamanin bekledigi sema).
    return json(fnCall.args, 200);
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

interface MetricInfo {
  id: string;
  name: string;
  type: string;
  unit?: string;
  target?: number;
  bool_has_value?: boolean;
}

interface ChatTurn {
  role: "user" | "assistant";
  content: string;
}
