# Supabase EU Hosting, Encryption, TLS, and Storage TTL — Fact-Finding

Fact-finding only. No recommendations, decisions, or opinions are included below.

Research date: 2026-09-09. All citations point to Supabase's official documentation (supabase.com/docs, supabase.com/security, supabase.com) unless explicitly labeled "secondary." Primary-source pages were fetched directly (raw HTML) and quoted verbatim where indicated with quotation marks.

---

## 1. EU Region Hosting

### What EU regions exist

Supabase's regions page lists a "Europe" **general region grouping** plus six **specific** AWS regions in Europe. Directly stated on the page:

- General regions (auto-assigned by capacity): Americas → `East US (North Virginia)`, **Europe → `Central EU (Frankfurt)`**, APAC → `Southeast Asia (Singapore)`. [Supabase docs: Available regions](https://supabase.com/docs/guides/platform/regions)
- Specific regions (full list, as stated on the page and cross-confirmed on [Supabase: Regions](https://supabase.com/regions)):
  - `us-west-1` — West US (North California)
  - `us-west-2` — West US (Oregon)
  - `us-east-1` — East US (North Virginia)
  - `us-east-2` — East US (Ohio)
  - `ca-central-1` — Canada (Central)
  - **`eu-west-1` — West EU (Ireland)**
  - **`eu-west-2` — West Europe (London)**
  - **`eu-west-3` — West EU (Paris)**
  - **`eu-central-1` — Central EU (Frankfurt)**
  - **`eu-central-2` — Central Europe (Zurich)**
  - **`eu-north-1` — North EU (Stockholm)**
  - `ap-south-1` — South Asia (Mumbai)
  - `ap-southeast-1` — Southeast Asia (Singapore)
  - `ap-northeast-1` — Northeast Asia (Tokyo)
  - `ap-northeast-2` — Northeast Asia (Seoul)
  - `ap-southeast-2` — Oceania (Sydney)
  - `sa-east-1` — South America (São Paulo)

So the EU/Europe-labeled options are: **Ireland, London, Paris, Frankfurt, Zurich, Stockholm** (six specific regions) plus the general "Europe" grouping (which auto-assigns to available capacity, and per Supabase's own GDPR page, that grouping "also includes London (UK) and Zurich (Switzerland)" — see caveat below).
[Supabase docs: Available regions](https://supabase.com/docs/guides/platform/regions) · [Supabase: Regions](https://supabase.com/regions) · [Supabase docs: Data Residency](https://supabase.com/security)

### EU-member-state caveat (directly stated by Supabase)

Supabase's own GDPR compliance page explicitly distinguishes EU-member-state regions from GDPR-adequate-but-non-EU regions. Verbatim quote from the live page:

> "London (UK) and Zurich (Switzerland) — both have GDPR-adequacy data protection regimes, but neither is an EU member state. If your compliance requirements call for data to stay within the EU specifically, choose a specific EU region rather than the general Europe grouping."

> "Choosing a region is a data-location control and does not make your application GDPR compliant on its own. Backups, logs, data exported to external systems, Edge Function execution, and sub-processors can affect your data residency and international transfer analysis."

[Supabase docs: GDPR compliance and Supabase](https://supabase.com/docs/guides/security/gdpr-compliance)

This means that of the six "EU-labeled" regions, **Ireland, Paris, Frankfurt, and Stockholm are actual EU member states**, while **London and Zurich are non-EU jurisdictions that Supabase's docs group under "Europe."** Supabase's docs do not restate this EU-membership distinction on the regions page itself — it appears only on the GDPR compliance page.

### What determines residency

> "Each Supabase project is deployed to a single primary region, and your project's primary Postgres database, Auth service, and Storage objects are hosted in that region. Choosing a specific region within the EU pins these services to that exact AWS region."
[Supabase docs: GDPR compliance and Supabase](https://supabase.com/docs/guides/security/gdpr-compliance)

> "When you create a project in an AWS region, your Postgres database, Auth service, and Storage objects are hosted in that region."
[Supabase: Security](https://supabase.com/security)

### Region choice at project creation, and changing it later

Directly stated: region is selected during project creation, and it is a one-time, infrastructure-level choice.

> "Each Supabase project is provisioned on hardware in the chosen region, so it is bound to a region at the infrastructure level."
>
> "Therefore, the process to change the region of a Supabase Project is to create a new project in the desired region and migrate your existing project using the migrations guide."
[Supabase docs: Change Project Region (Troubleshooting)](https://supabase.com/docs/guides/troubleshooting/change-project-region-eWJo5Z)

The linked migration guide confirms this is a manual, full data-migration process (dump/restore or "Restore to another project" on paid plans with backups), not an in-place region switch:

> "Project migration is primarily for changing regions or upgrading to new major versions [of the platform]."
[Supabase docs: Migrating within Supabase](https://supabase.com/docs/guides/platform/migrating-within-supabase)

Separately, Supabase's "Project Transfers" feature is explicitly **not** a region-change mechanism — it only moves a project between organizations/billing entities without an infrastructure change (per the docs page title and description found during research: [Supabase docs: Project Transfers](https://supabase.com/docs/guides/platform/project-transfer)).

### Uncertainty / gaps

- The regions page itself ([Available regions](https://supabase.com/docs/guides/platform/regions)) does not, on its own, restate whether region selection is one-time/immutable — that fact is stated only on the separate Troubleshooting page cited above. Both pages are official Supabase docs, so this is not a gap, just a note that the facts are split across two pages.
- Supabase docs do not explicitly enumerate "GDPR-adequate but non-EU" caveats anywhere except the GDPR-compliance page; a reader relying only on the regions list or the marketing regions page would not learn that London/Zurich are non-EU.

---

## 2. At-Rest Encryption

### Stated default (Postgres + Storage combined)

Supabase's official security page states, as a single combined statement covering all customer data (which includes both the Postgres database and Storage objects, per the Data Residency statement on the same page):

> "All customer data is encrypted at rest with AES-256 and in transit via TLS."
>
> "Sensitive information like access tokens and keys are encrypted at the application level before they are stored in the database."
[Supabase: Security](https://supabase.com/security)

**Directly stated:** AES-256 at rest for all customer data. **Inferred (not explicitly separated by Supabase):** the statement is not broken out separately for "Postgres database" vs. "Storage object storage" — it is a single blanket statement covering "all customer data." Because the same page's "Data Residency" section states that Postgres, Auth, and Storage objects are all hosted together in the chosen AWS region, it is a reasonable inference that the AES-256-at-rest statement applies to both, but Supabase's docs do not give a separate, explicit sentence for Storage specifically (e.g., "Storage objects are encrypted with AES-256 via S3/EBS encryption").

### Underlying mechanism (AWS-managed encryption)

Supabase's docs do not explicitly spell out "this is AWS's provider-managed disk/volume encryption" in the pages checked (security page, GDPR page, SOC2 page, HIPAA page). Supabase is known to run on AWS infrastructure (stated elsewhere in Supabase's docs, e.g., region pages reference "AWS region"), so that Postgres/Storage AES-256-at-rest encryption is implemented via the underlying AWS infrastructure is a reasonable **inference**, not a claim Supabase's docs state in those words on the pages reviewed.

### Customer-managed keys / BYOK (CMEK)

**Directly stated as NOT recommended / not offered in that form:** Supabase does provide a project-level "root encryption key" for its optional **Vault** / **pgsodium** column-encryption features (used for encrypting specific columns inside the app, not for the platform's disk-level AES-256 at-rest encryption), and this is the closest official concept to "customer key control." Verbatim from the docs:

> "Where is the key stored? Supabase creates and manages a unique encryption key for each project in our secured backend systems. We keep this key safe and separate from your data. You remain in control of your key - the Management API endpoint returns your project's 64-character hex root key so you can decrypt your data outside of Supabase or copy it to another project."
[Supabase docs: Vault](https://supabase.com/docs/guides/database/vault)

> "Each Supabase project has its own root encryption key. Same-project operations - pausing and restoring, and Point-in-Time or in-place restores - keep the same key, so your secrets stay readable automatically."
[Supabase docs: Vault](https://supabase.com/docs/guides/database/vault)

However, Supabase explicitly discourages using this feature at all:

> "At this time, we do not recommend using either [pgsodium or Vault encryption] on the Supabase platform due to their high level of operational complexity and misconfiguration risk. Note that Supabase projects are encrypted at rest by default which likely is [sufficient for many compliance needs]."
[Supabase docs: pgsodium (pending deprecation): Encryption Features](https://supabase.com/docs/guides/database/extensions/pgsodium)

**Important distinction:** this "root encryption key" mechanism is for the opt-in Vault/pgsodium *column-level* encryption feature — it is retrievable/portable by the customer, but it is a Supabase-generated, Supabase-managed key for a separate, discouraged feature. It is **not** the same as a bring-your-own-key (BYOK) or customer-managed-key (CMEK) scheme for the platform's default AES-256 disk-level encryption of the whole Postgres database or Storage bucket (e.g., there is no documented ability to supply your own AWS KMS key ARN for Supabase-managed RDS/EBS/S3-equivalent encryption).

### Uncertainty / gaps

- Supabase's docs do not explicitly state, anywhere found, that CMEK/BYOK for the platform-level AES-256 at-rest encryption is "not available" in those exact words — its absence is inferred from the fact that no such feature, setting, or docs page describing it exists anywhere in Supabase's official documentation, security page, SOC2 page, HIPAA page, or GDPR page reviewed.
- No separate, explicit sentence distinguishes "Postgres at-rest encryption" from "Storage at-rest encryption" — both are covered by one blanket "all customer data" statement.
- The SOC2 compliance page ([SOC 2 Compliance and Supabase](https://supabase.com/docs/guides/security/soc-2-compliance)) and HIPAA compliance page ([HIPAA Compliance and Supabase](https://supabase.com/docs/guides/security/hipaa-compliance)) were checked directly and contain **no** encryption-at-rest or TLS-version detail — they are procedural/responsibility-model pages, not technical specification pages.

---

## 3. TLS Version

### What is directly stated

Supabase's SSL enforcement docs describe SSL/TLS **enforcement** (on/off) and Postgres **SSL modes**, but do not state a specific TLS protocol version number (e.g., "1.2" or "1.3") anywhere on that page:

> "Disabling SSL enforcement only applies to connections to Postgres, Supavisor (shared Connection Pooler) and PgBouncer (dedicated Connection Pooler); all HTTP APIs offered by Supabase (e.g., PostgREST, Storage, Auth) automatically enforce SSL on all incoming connections."
[Supabase docs: Postgres SSL Enforcement](https://supabase.com/docs/guides/platform/ssl-enforcement)

> "The strongest mode offered by Postgres is `verify-full` and this is the mode you most likely want to use when SSL enforcement is enabled. To use `verify-full` you will need to download the Supabase CA certificate..."
[Supabase docs: Postgres SSL Enforcement](https://supabase.com/docs/guides/platform/ssl-enforcement)

That page confirms SSL enforcement (and hence encryption-in-transit) covers **both** direct Postgres and both poolers (Supavisor and PgBouncer), as well as all HTTP APIs (PostgREST/Storage/Auth) automatically — but again, without naming a TLS protocol version.

Supabase's security page states only:

> "All customer data is encrypted at rest with AES-256 and in transit via TLS."
[Supabase: Security](https://supabase.com/security)

— again, "via TLS" with no version number specified.

### Explicit search for a stated TLS version number

The following official Supabase pages were fetched and searched directly (raw HTML, not summaries) for a literal "TLS 1.2" / "TLS 1.3" / "TLSv1.x" string, and **none contained such a string**:
- [Postgres SSL Enforcement](https://supabase.com/docs/guides/platform/ssl-enforcement)
- [Supabase Security](https://supabase.com/security)
- [Supabase docs: Security overview](https://supabase.com/docs/guides/security)
- [Supabase docs: Network Restrictions](https://supabase.com/docs/guides/platform/network-restrictions)
- [Supabase docs: Connecting to Postgres](https://supabase.com/docs/guides/database/connecting-to-postgres)
- [Supabase docs: SOC 2 Compliance and Supabase](https://supabase.com/docs/guides/security/soc-2-compliance)
- [Supabase docs: HIPAA Compliance and Supabase](https://supabase.com/docs/guides/security/hipaa-compliance)
- [Supabase blog: Supabase is SOC2 compliant](https://supabase.com/blog/supabase-soc2)

### Secondary sources (unverified against primary docs)

Several third-party/AI-generated web summaries (secondary, not confirmed against the actual page text) asserted "Supabase encrypts all traffic via HTTPS/TLS 1.2+", e.g. summarized from a UI Bakery blog post ("Supabase Security: What Enterprise Teams Need to Know," secondary) and similar aggregator content. These claims could **not** be corroborated in the raw text of any official Supabase docs page checked above. They are flagged here as **secondary and unverified**, not as confirmed Supabase-stated facts.

### Uncertainty / gaps — explicit statement

**Supabase's docs do not appear to explicitly state a minimum or supported TLS protocol version number** (neither "TLS 1.2 minimum" nor "TLS 1.3 supported/preferred") for any of: direct Postgres connections, Supavisor pooler connections, PgBouncer pooler connections, or the Storage/REST/Auth HTTPS APIs, on any official page located during this research. What Supabase *does* explicitly state is that:
1. SSL/TLS encryption is enforceable (and can be toggled) for Postgres/Supavisor/PgBouncer connections, and
2. all HTTP APIs (PostgREST, Storage, Auth) "automatically enforce SSL on all incoming connections" without a configurable option to disable it.

No page found states whether TLS 1.0/1.1 are actively rejected, or whether TLS 1.3 is offered/preferred over 1.2. This should be treated as an open question against Supabase's own documentation, not a settled fact.

---

## 4. Storage Object Auto-Deletion / TTL

### No native TTL/lifecycle-rule feature

No official Supabase documentation page found (Storage guides, Storage management pages, Storage API reference) describes a native object-level TTL or S3-style lifecycle-rule feature for Supabase Storage (e.g., "expire after N days," "auto-delete after N hours"). Specifically:

- [Supabase docs: Delete Objects (Storage)](https://supabase.com/docs/guides/storage/management/delete-objects) — describes only manual/programmatic deletion via the Storage API `remove` method; no TTL/expiration/lifecycle feature is mentioned anywhere on the page.
- A community feature request explicitly asking Supabase to expose "AWS S3 lifecycle management" for Storage remains **unanswered by any Supabase team member**, per the GitHub Discussions thread (secondary/community source, not official docs):
  > User request: expose AWS S3 lifecycle management "to prevent needing extra crons or events to clear storage." Status: **Unanswered** — no official Supabase response.
  [GitHub Discussion (secondary, supabase org discussions): Expiring objects (Storage) #20171](https://github.com/orgs/supabase/discussions/20171)

This absence is treated here as **Supabase docs do not appear to explicitly state** that a native TTL feature exists, corroborated by the fact that the relevant official Storage-management docs page describes only manual deletion, and the only related feature request is unresolved.

### SQL-only deletion of storage.objects rows does NOT delete the underlying file

Directly and explicitly stated in the official docs — this is an important constraint for any scheduled-cleanup approach:

> "Deleting objects should always be done via the Storage API and NOT via a SQL query. Deleting objects via a SQL query will not remove the object from the bucket and will result in the object being orphaned."
[Supabase docs: Delete Objects (Storage)](https://supabase.com/docs/guides/storage/management/delete-objects)

This means a pg_cron job that only runs `DELETE FROM storage.objects WHERE ...` would remove the database row/metadata but leave the actual file object behind in the bucket ("orphaned") — it would not achieve true storage-space deletion. The docs recommend the Storage API (`remove` method, limited to 1,000 objects per call, per the same page) for actual object removal.

### What Supabase's own docs do recommend/show for scheduled deletion (of Postgres rows, not Storage objects specifically)

Supabase's own Postgres-data-deletion guide explicitly recommends pg_cron for scheduled row deletion (a general Postgres-table pattern, not Storage-object-specific):

> "Combine soft deletes with a scheduled hard-delete job (using pg_cron) to permanently remove old soft-deleted rows in batches during low-traffic periods."
[Supabase docs: Deleting data and dropping objects safely](https://supabase.com/docs/guides/database/postgres/data-deletion)

Supabase's own **Cron** feature quickstart shows an official worked example of a pg_cron scheduled job that runs a SQL statement to delete old *table* rows (again, a generic Postgres table, not a Storage bucket object):

> Example job named `saturday-cleanup`, scheduled `'30 3 * * 6'` (Saturday 3:30 AM GMT), running:
> `delete from events where event_time < now() - interval '1 week'`
[Supabase docs: Cron Quickstart](https://supabase.com/docs/guides/cron/quickstart)

Supabase's Cron overview page confirms Cron jobs can trigger either SQL/DB functions directly, or an HTTP call including an Edge Function:

> "Every Job can run SQL snippets or database functions with zero network latency or make an HTTP request, such as invoking a Supabase Edge Function, with ease."
[Supabase docs: Cron](https://supabase.com/docs/guides/cron)

### Synthesis of what Supabase's own docs support (fact, not recommendation)

Putting the above official statements together as facts (not as a recommendation from this research):
- Supabase's docs show pg_cron scheduled SQL deletion as an officially documented pattern for expiring **table rows** (events/data-deletion examples).
- Supabase's docs explicitly warn that this same SQL-deletion pattern, if pointed at `storage.objects`, will **not** delete the actual file and will orphan it — the Storage API must be used for actual object removal.
- Supabase's Cron feature explicitly supports invoking an Edge Function on a schedule (in addition to or instead of running SQL directly), which is the mechanism by which a scheduled job could call the Storage API (Edge Functions can use the Storage API/service-role key) to actually remove expired files.
- No official Supabase docs page found combines these into a single explicit worked example titled "delete an expired storage file after N hours" — the closest official materials are the generic Cron quickstart (row deletion) and the Storage delete-objects warning (orphaning), reviewed separately above. The specific "expiring storage objects" pattern (storing an `expires_at` timestamp in `storage.objects.user_metadata`, then a scheduled function/Edge Function that selects expired rows and deletes them via the Storage API) appears only in **community/secondary sources** (e.g., a GitHub Discussion and a third-party "supa-file-helper" repository), not in Supabase's own official documentation.

### Uncertainty / gaps — explicit statement

- **Supabase docs do not appear to explicitly state** a recommended, end-to-end, official method for "delete this storage file automatically after N hours." The two closest official facts — (a) pg_cron-based scheduled SQL deletion of table rows is documented, and (b) SQL deletion must not be used against `storage.objects` because it orphans the file — are each individually documented, but Supabase has not published an official guide that combines them into a supported storage-TTL pattern.
- The specific "Edge Function invoked by pg_cron/Supabase Cron to expire Storage files" pattern is corroborated only by secondary/community sources (GitHub Discussions, third-party blogs/repos), not by an official Supabase docs page or blog post found during this research.
