// Deliberately trivial: this function's only job is to prove the CI deploy
// pipeline (ticket 21) can reach a live, deployed Edge Function end to end.
// Real functions (createShare, push notifications, GDPR cleanup) land in
// their own tickets.
import "@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(() =>
  Response.json({ status: "ok" }),
);

/* To invoke locally:

  1. Run `supabase start`
  2. curl -i http://127.0.0.1:54321/functions/v1/health

*/
