// Ticket 06 / ticket 11: send one of the caller's own Alarm Calls to a
// friend. Runs entirely with the service-role client past the caller's own
// identity check, because it has to read/write across the sender and
// recipient's rows — no single user's RLS-scoped client can do that.
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

function fail(status: number, message: string): Response {
  return Response.json({ error: message }, { status });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return fail(405, "method not allowed");

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return fail(401, "missing authorization");

  let body: { alarmCallId?: string; recipientId?: string };
  try {
    body = await req.json();
  } catch {
    return fail(400, "invalid JSON body");
  }
  const { alarmCallId, recipientId } = body;
  if (!alarmCallId || !recipientId) {
    return fail(400, "alarmCallId and recipientId are required");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Identifies the caller from their own JWT — RLS-scoped, so it can only
  // ever resolve to whoever actually sent the request.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) return fail(401, "not authenticated");
  const senderId = userData.user.id;

  if (senderId === recipientId) return fail(400, "cannot share with yourself");

  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: alarmCall, error: alarmCallError } = await admin
    .from("alarm_calls")
    .select("id, owner_id, storage_path")
    .eq("id", alarmCallId)
    .maybeSingle();
  if (alarmCallError) return fail(500, alarmCallError.message);
  if (!alarmCall || alarmCall.owner_id !== senderId) return fail(404, "alarm call not found");

  const { data: connection, error: connectionError } = await admin
    .from("friend_connections")
    .select("id")
    .eq("status", "accepted")
    .or(
      `and(requester_id.eq.${senderId},addressee_id.eq.${recipientId}),and(requester_id.eq.${recipientId},addressee_id.eq.${senderId})`,
    )
    .maybeSingle();
  if (connectionError) return fail(500, connectionError.message);
  if (!connection) return fail(403, "not friends with that recipient");

  const { data: share, error: insertError } = await admin
    .from("shares")
    .insert({
      alarm_call_id: alarmCall.id,
      friend_connection_id: connection.id,
      sender_id: senderId,
      recipient_id: recipientId,
    })
    .select("id")
    .single();
  if (insertError) return fail(500, insertError.message);

  const { data: fileData, error: downloadError } = await admin.storage
    .from("alarm-calls")
    .download(alarmCall.storage_path);
  if (downloadError || !fileData) {
    return fail(500, downloadError?.message ?? "could not read source clip");
  }

  const shareStoragePath = `${share.id}.m4a`;
  const { error: uploadError } = await admin.storage
    .from("shares")
    .upload(shareStoragePath, fileData, { contentType: "audio/mp4" });
  if (uploadError) return fail(500, uploadError.message);

  // Fan out to every one of the recipient's *current* Alarms (ADR-0002) —
  // never retroactively to Alarms they create afterward. This has to finish
  // before uploaded_at is flipped below: that flip is what fires the push,
  // and the push claims "your Queue count went up" — if the fan-out failed,
  // there'd be nothing to back that up.
  const { data: recipientAlarms, error: alarmsError } = await admin
    .from("alarms")
    .select("id")
    .eq("owner_id", recipientId);
  if (alarmsError) return fail(500, alarmsError.message);

  if (recipientAlarms && recipientAlarms.length > 0) {
    const { error: queueError } = await admin.from("queue_entries").insert(
      recipientAlarms.map((alarm) => ({
        alarm_id: alarm.id,
        share_id: share.id,
        alarm_call_id: alarmCall.id,
      })),
    );
    if (queueError) return fail(500, queueError.message);
  }

  // Flipping uploaded_at is what fires the shares_after_upload trigger (see
  // the migration) — sending the push is decoupled from this request.
  const { error: updateError } = await admin
    .from("shares")
    .update({ storage_path: shareStoragePath, uploaded_at: new Date().toISOString() })
    .eq("id", share.id);
  if (updateError) return fail(500, updateError.message);

  return Response.json({ shareId: share.id });
});
