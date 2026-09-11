# 06: Share sending & Queue population

**What to build:** A user shares a Library clip with a friend; it fans out to every one of that friend's current Alarms, their Queue count increments, and a push notification arrives on their device.

**Blocked by:** 03 (Friend discovery & connection), 05 (Alarm Call recording & Library)

- [ ] `shares` table (`alarm_call_id`, `friend_connection_id`, `sender_id`, `recipient_id`, `storage_path`, timestamps, `expires_at` default now+48h, `deleted_at`)
- [ ] `queue_entries` table (`alarm_id`, `share_id`, `alarm_call_id`, `received_at`, `played_at`), unique per `(alarm_id, share_id)`, FIFO index
- [ ] `device_tokens` table with upsert-reassign registration on token reuse (`on conflict (apns_token) do update`) and invalidation on APNs 410
- [ ] `createShare(alarmCallId, recipientId)` Edge Function: validates ownership + an accepted Friend Connection, inserts the `shares` row, server-side copies bytes from `alarm_calls.storage_path` into a new per-Share Storage object, writes `shares.storage_path`
- [ ] Share fans out to every one of the recipient's *current* Alarms (not Alarms created afterward), inserting one `queue_entries` row per Alarm
- [ ] Completing the copy flips `shares.uploaded_at`, which fires a Database Webhook
- [ ] Database Webhook → Edge Function signs an ES256 JWT with the app's `.p8` key and POSTs directly to APNs (best-effort, no retry/backoff) — "new Alarm Call received" notification type
- [ ] RLS on `queue_entries` permits the owner to `select` metadata only (`id`, `received_at`, `played_at`), never `storage_path`
- [ ] `getShareDownloadUrl(shareId)` Edge Function: validates caller is `shares.recipient_id` and not expired/deleted, mints a presigned download URL, stamps `downloaded_at`
- [ ] End-to-end: sender shares a clip, recipient's Queue count increments across all their current Alarms, and a push notification is received on the recipient's device
