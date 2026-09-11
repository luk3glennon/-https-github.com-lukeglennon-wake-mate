# 08: Share expiry cleanup & GDPR deletion

**What to build:** Undownloaded Shares are deleted within the 48-hour GDPR deletion window, orphaned Queue entries are cleaned up, and both sender and recipient are notified.

**Blocked by:** 06 (Share sending & Queue population)

- [ ] Scheduled Supabase Edge Function (native Scheduled Edge Functions, no `pg_cron`, no external scheduler) queries for Shares expired or downloaded per the 48h window
- [ ] On 48h expiry with no download: deletes `shares.storage_path` via the Storage API, sets `deleted_at`, removes the orphaned `queue_entries` row(s)
- [ ] On confirmed download (`downloaded_at` set), cleanup can happen ahead of the 48h timeout rather than waiting for it
- [ ] "Share expired without being downloaded" push sent to both sender and recipient on expiry (no auto-resend; sender can manually re-Share via a fresh `createShare`)
- [ ] Verify deletion actually happens in both Postgres (`deleted_at`, `storage_path` cleared) and Storage (object removed) within the window
- [ ] Encryption at rest and TLS are provider/OS defaults — no additional work, but confirm no plaintext secrets or unencrypted overrides were introduced by this job
