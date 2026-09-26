// Ticket 06 / ticket 18: fired by the shares_after_upload trigger (see the
// migration) when a Share finishes its server-side copy. Sends a single
// "new Alarm Call received" push, direct to APNs, best-effort — no
// retry/backoff, no queueing. verify_jwt is off for this function (see the
// migration's header comment for why); this never trusts its input for
// anything beyond "which recipient to look up device tokens for".
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const APNS_HOST = "https://api.push.apple.com";
const APNS_TOPIC = "com.wakemate.alarmcall";

function fail(status: number, message: string): Response {
  return Response.json({ error: message }, { status });
}

Deno.serve(async (req) => {
  let payload: { recipient_id?: string };
  try {
    payload = await req.json();
  } catch {
    return fail(400, "invalid JSON body");
  }

  const recipientId = payload.recipient_id;
  if (!recipientId) return fail(400, "recipient_id is required");

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: tokens, error: tokensError } = await admin
    .from("device_tokens")
    .select("apns_token")
    .eq("user_id", recipientId)
    .is("invalidated_at", null);
  if (tokensError) return fail(500, tokensError.message);
  if (!tokens || tokens.length === 0) return Response.json({ sent: 0 });

  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const authKeyBase64 = Deno.env.get("APNS_AUTH_KEY_BASE64");
  if (!keyId || !teamId || !authKeyBase64) {
    // Best-effort (ticket 18) — missing config just means no push goes out
    // this time, not a failure the webhook trigger needs to know about.
    return Response.json({ sent: 0, skipped: "APNs not configured" });
  }

  const signingKey = await importAPNsSigningKey(authKeyBase64);
  const jwt = await signAPNsJWT(teamId, keyId, signingKey);

  let sent = 0;
  for (const { apns_token: token } of tokens) {
    try {
      const response = await fetch(`${APNS_HOST}/3/device/${token}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": APNS_TOPIC,
          "apns-push-type": "alert",
          "apns-priority": "10",
        },
        body: JSON.stringify({
          aps: {
            alert: { title: "New Alarm Call", body: "A friend sent you a new Alarm Call." },
            sound: "default",
          },
        }),
      });

      if (response.status === 410) {
        await admin
          .from("device_tokens")
          .update({ invalidated_at: new Date().toISOString() })
          .eq("apns_token", token);
      } else if (response.ok) {
        sent += 1;
      }
    } catch {
      // No retry/backoff (ticket 18) — one token's network failure must not
      // stop the others in this loop.
    }
  }

  return Response.json({ sent });
});

async function importAPNsSigningKey(pemBase64: string): Promise<CryptoKey> {
  const pem = atob(pemBase64);
  const der = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bytes = Uint8Array.from(atob(der), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey("pkcs8", bytes, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
}

function base64url(input: Uint8Array | string): string {
  const raw = typeof input === "string" ? input : String.fromCharCode(...input);
  return btoa(raw).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function signAPNsJWT(teamId: string, keyId: string, key: CryptoKey): Promise<string> {
  const encodedHeader = base64url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const encodedPayload = base64url(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) }));
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64url(new Uint8Array(signature))}`;
}
