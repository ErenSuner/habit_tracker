// Supabase Edge Function: "ai-fill"
// -----------------------------------------------------------------------------
// Kullanicinin serbest metnini ("bugun 1 saat kostum, 30 sayfa okudum...")
// alir, metrik listesiyle birlikte Claude'a gonderir ve yapilandirilmis
// giris onerileri dondurur. Anthropic API anahtari SADECE burada (sunucuda)
// bulunur; uygulamaya gomulmez.
//
// Kurulum (terminalden, bir kez):
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//   supabase functions deploy ai-fill
// -----------------------------------------------------------------------------

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");

// Kullanilacak model. Bu gorev (gunu yapilandirilmis girise cevirme) basit
// oldugu icin en ucuz/hizli model Haiku secildi. Daha kaliteli istersen
// "claude-sonnet-4-6" ya da "claude-opus-4-8" yapabilirsin.
const MODEL = "claude-haiku-4-5";

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
    if (!ANTHROPIC_API_KEY) {
      return json({ error: "Sunucuda ANTHROPIC_API_KEY tanimli degil." }, 500);
    }

    const body = await req.json();
    const message: string = body.message ?? "";
    const metrics: MetricInfo[] = body.metrics ?? [];
    const history: ChatTurn[] = body.history ?? [];

    if (!message.trim()) {
      return json({ error: "Mesaj bos." }, 400);
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

    // Modelin yapilandirilmis cevap vermesi icin tek bir arac (tool) tanimlariz
    // ve onu kullanmaya zorlariz.
    const tool = {
      name: "propose_day_entries",
      description:
        "Kullanicinin anlattiklarini takip uygulamasi girislerine cevir.",
      input_schema: {
        type: "object",
        properties: {
          reply: {
            type: "string",
            description: "Kullaniciya gosterilecek kisa Turkce ozet/yanit.",
          },
          entries: {
            type: "array",
            items: {
              type: "object",
              properties: {
                metric_id: { type: "string" },
                metric_name: { type: "string" },
                type: {
                  type: "string",
                  enum: ["numeric", "boolean", "tag", "text"],
                },
                num_value: { type: ["number", "null"] },
                bool_value: { type: ["boolean", "null"] },
                text_value: { type: ["string", "null"] },
                tags: { type: "array", items: { type: "string" } },
              },
              required: ["metric_id", "type"],
            },
          },
        },
        required: ["reply", "entries"],
      },
    };

    const messages = [
      ...history.map((t) => ({ role: t.role, content: t.content })),
      { role: "user", content: message },
    ];

    const anthropicRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1024,
        system,
        tools: [tool],
        tool_choice: { type: "tool", name: "propose_day_entries" },
        messages,
      }),
    });

    if (!anthropicRes.ok) {
      const errText = await anthropicRes.text();
      return json({ error: `Claude API hatasi: ${errText}` }, 502);
    }

    const data = await anthropicRes.json();
    // Zorunlu arac kullanimi nedeniyle cevap bir tool_use blogu icerir.
    const toolUse = (data.content ?? []).find(
      (b: { type: string }) => b.type === "tool_use",
    );

    if (!toolUse) {
      return json({ error: "Model yapilandirilmis cevap dondurmedi." }, 502);
    }

    return json(toolUse.input, 200);
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
}

interface ChatTurn {
  role: "user" | "assistant";
  content: string;
}
