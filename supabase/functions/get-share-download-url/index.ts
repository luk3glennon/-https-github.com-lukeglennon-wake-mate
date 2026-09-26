// Ticket 06 / ticket 11: mint a short-lived download URL for a Share's
// audio, checked server-side against who it was actually sent to (never
// trust storage_path to the client until this passes).
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

function fail(status: number, message: string): Response {
  return Response.json({ error: message }, { status });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return fail(405, "method not allowed");

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return fail(401, "missing authorization");

  let body: { shareId?: string };
  try {
    body = await req.json();
  } catch {
    return fail(400, "invalid JSON body");
  }
  if (!body.shareId) return fail(400, "shareId is required");

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) return fail(401, "not authenticated");

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { data: share, error: shareError } = await admin
    .from("shares")
    .select("id, recipient_id, storage_path, expires_at, deleted_at")
    .eq("id", body.shareId)
    .maybeSingle();
  if (shareError) return fail(500, shareError.message);
  if (!share || share.recipient_id !== userData.user.id) return fail(404, "share not found");
  if (share.deleted_at || !share.storage_path) return fail(410, "share is no longer available");
  if (new Date(share.expires_at) <= new Date()) return fail(410, "share has expired");

  const { data: signed, error: signError } = await admin.storage
    .from("shares")
    .createSignedUrl(share.storage_path, 60 * 60);
  if (signError || !signed) return fail(500, signError?.message ?? "could not sign url");

  await admin
    .from("shares")
    .update({ downloaded_at: new Date().toISOString() })
    .eq("id", share.id)
    .is("downloaded_at", null);

  return Response.json({ url: signed.signedUrl });
});
