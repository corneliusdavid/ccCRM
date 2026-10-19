# ccCRM

A small, personal CRM for ABS Cloud and other customers, built in Delphi on RAD Server and Firebird 5, with a mobile (FMX) client. **Wave (waveapps.com) is the master for billing/contact data**; this project adds the things Wave doesn't have: customer type and status, notes, extra contacts, an event log, user counts and an Active Directory link.

> **Status (2026-10-11): the Firebird 5 schema is created** (5 tables, 1 view, 1 procedure, 2 triggers, 4 identity sequences, lookup rows seeded; run in DBeaver). Not yet done: end-to-end test of the log triggers, the Wave sync, RAD Server, the app. `wave-customers.graphql` has not been run. This README is the summary of the design conversation so the work can resume cold.

This project was split out of the ABS RDWeb repo (`E:\Delphi\ABS\RDWeb\ABS RDWeb`) on purpose: that repo is deployed by copying files to IIS, and this one has a different deployment (RAD Server + database + mobile app).

---

## Goals

1. Keep notes and a dated history for every customer.
2. Look up emails and phone numbers quickly (including from a phone).
3. Generate an email list for everyone in a group (for example all Active ABS Cloud customers) to paste into a BCC line.
4. Replace the current CRM (bluecamroo.com, which isn't liked). Nothing needs to be imported from it; any notes will be re-entered manually. Trello data will also be merged in manually.
5. Avoid two separate sets of customer records: Wave stays the master, this app caches and extends it.

Non-goals (for now): prospect tracking (all customers come from the ABS software vendor and are billable on arrival), document storage, follow-up reminders, sending the actual email blast.

---

## Key decisions

| Topic | Decision |
|---|---|
| Master data | Wave. A customer must exist in Wave before it exists here. |
| Writes to Wave | **None.** The app never deletes or modifies Wave data. It is read-only toward Wave. |
| Customers disappearing from Wave | Sync sets `IN_WAVE = 0`; the row, notes and log are kept. Sync never deletes; you can delete an obsolete record yourself (app: Details, **Delete**), which removes its contacts and log too. |
| Database | **Firebird 5** (switched from InterBase). An existing Firebird database will be imported later (check its version; older files need a `gbak` backup/restore). Open check: that your FireDAC version accepts the Firebird 5 client library. |
| Server | Existing RAD Server on an ABS Cloud server. Not the RDWeb pages. |
| Client | FMX mobile app first (tap-to-call, tap-to-email, search). A web page can reuse the same endpoints later. |
| Wave credentials | Full Access token, stored server-side in RAD Server config only. Never in the app, never in RDWeb. |
| Type / Status | Two lookup tables (editable): Type = ABS, ABS Cloud, Retail Pro, Custom, Web; Status = Active, Inactive. |
| Main contact | Lives in `CUSTOMER` (from Wave). Additional people live in `CONTACT`. |
| AD link | One AD group per customer, stored as `CUSTOMER.AD_GROUP` (unique). No mapping table. |
| User count | `CUSTOMER.USER_COUNT`, entered manually for now; later computed from AD group membership. |
| Notes vs log | `CUSTOMER.NOTES` = standing information. `CUSTOMER_LOG` = dated events, automatic and manual. |
| Logo | `CUSTOMER.LOGO` blob (Wave has no logo field). Documents are deferred. |

---

## Architecture

```
 Wave (GraphQL) --nightly / on demand--> RAD Server (sync) --> Firebird 5
                                              ^                    |
 AD export (PowerShell, later) -----------> importer               |
 Firebird (later) -------------------------> importer              |
                                                                    v
                                         RAD Server REST resources
                                                    |
                                          FMX mobile app (and web, later)
```

- **Importers are separate units** (Wave, AD, later Firebird) writing to the same tables, so adding a source doesn't mean rewriting anything.
- **Wave has no customer webhooks** (per secondary sources), so the sync is polling: nightly plus a "refresh now" button. 82 customers is well within rate limits.
- RDWeb can later call a read-only RAD Server endpoint (for example to show a customer name on its Admin page). The RDWeb pages currently derive customers from AD via PowerShell and have no database; this project doesn't change that.

### Data ownership

- **Wave-owned columns** (`NAME`, `FIRST_NAME`, `LAST_NAME`, `EMAIL`, `PHONE`, `MOBILE`, `WEBSITE`, address fields, `IN_WAVE`, `SYNCED_AT`): overwritten by the sync.
- **Your columns** (`TYPE_ID`, `STATUS_ID`, `AD_GROUP`, `USER_COUNT`, `NOTES`, `LOGO`, plus everything in `CONTACT` and `CUSTOMER_LOG`): the sync never touches them.
- New customers arriving from Wave have `TYPE_ID` and `STATUS_ID` **NULL** (unclassified), which makes them easy to spot and classify. A default can be added if preferred.
- Wave's `internalNotes` field is intentionally unused (it's a single string; the log is better).

---

## Schema (see `schema.sql`)

| Table | Purpose |
|---|---|
| `CUSTOMER_TYPE` | Lookup: ABS, ABS Cloud, Retail Pro, Custom, Web (editable in the database; new types go in `migrations/`). |
| `CUSTOMER_STATUS` | Lookup: Active, Inactive (editable). |
| `CUSTOMER` | One row per Wave customer; key is the Wave ID (`VARCHAR(100) CHARACTER SET ASCII`, an opaque base64 string, don't parse it). |
| `CONTACT` | Additional people at a customer: name, email, phone, job title. |
| `CUSTOMER_LOG` | Timeline per customer. |

### CUSTOMER_LOG

- `EVENT_DATE` is when it happened and is **editable**, so old history can be typed in back-dated (for example "Customer signed up", 2020-04-29; "Customer added 1 user via email", 2022-08-10).
- `LOGGED_AT` is when the row was created (automatic).
- `ENTRY_SOURCE`: `'A'` written by triggers, `'M'` entered by hand (default).
- `FIELD_NAME`, `OLD_VALUE`, `NEW_VALUE` are filled for automatic entries; `SUMMARY` is always readable text (for example `Status: Active -> Inactive`).
- Triggers (`CUSTOMER_AI_LOG`, `CUSTOMER_AU_LOG`) log changes to type, status, user count, AD group, name, first/last name, email, phone, mobile, website, address and `IN_WAVE`. They fire no matter how the change was made (app, sync, DBeaver). Both call the `LOG_CHANGE` procedure, which builds the "Field: old -> new" summary, so tracking another column is a two-line addition to the update trigger.
- Sync-driven changes (for example an email changed in Wave) are logged too, as automatic entries.

### Email blast query

```sql
SELECT C.EMAIL
FROM CUSTOMER C
JOIN CUSTOMER_TYPE   T ON T.TYPE_ID   = C.TYPE_ID
JOIN CUSTOMER_STATUS S ON S.STATUS_ID = C.STATUS_ID
WHERE T.NAME = 'ABS Cloud' AND S.NAME = 'Active'
  AND C.IN_WAVE = 1 AND C.EMAIL <> '';
```

Type is a parameter, so any group can be blasted. Add `CONTACT.EMAIL` rows with a `UNION` to include extra contacts. The app only generates the list (copy a BCC string or export CSV); **sending** is deferred (it would need SMTP/Graph/SendGrid plus bounce and unsubscribe handling).

---

## Wave API notes

**Caveat: Wave's developer site returned 403 to the tool used in the design session, so these come from search snippets and third-party write-ups. Verify in your Wave developer portal.**

- GraphQL only: `https://gql.waveapps.com/graphql/public` (verified with an unauthenticated probe; the plain `/graphql` path returns 404 "Cannot POST /graphql"; ignore any REST v1 write-ups).
- Auth: **Full Access token** for personal/internal use (the sources say this doesn't require Wave Pro); OAuth 2 is for published apps and requires the connected business to have Wave Pro/Advisor (as of May 2025). Skim Wave's *Permitted Use* page to confirm an internal tool like this is covered.
- Rate limits (secondary source): 60 requests/minute per token, 5,000/day per application. Irrelevant at 82 customers.
- Customer fields seen in a real record: `id`, `name`, `firstName`, `lastName`, `email`, `phone`, `mobile`, `website`, `address { addressLine1 addressLine2 city province { code name } postalCode }`, `internalNotes`. Province code looks like `US-CA`.
- Pagination is `page` / `pageSize` with `pageInfo`. Queries are in `wave-customers.graphql` (unverified against the live schema).
- Wave data is clean: 82 customers, a mix of current ABS, former ABS and non-ABS.

---

## Sync rules (to implement)

1. Fetch all customers (loop pages).
2. For each: `UPDATE OR INSERT INTO CUSTOMER (...Wave-owned columns..., IN_WAVE, SYNCED_AT) VALUES (..., TRUE, CURRENT_TIMESTAMP) MATCHING (WAVE_ID)`. Only Wave-owned columns are listed, so your columns survive; new rows get NULL type/status. (Example at the bottom of `schema-programmability.sql`.)
3. Any `CUSTOMER` row not seen in this run: `UPDATE CUSTOMER SET IN_WAVE = FALSE WHERE IN_WAVE AND SYNCED_AT < :SYNC_START`.
4. Sync never `DELETE`s, never writes to Wave.
5. Use the field mapping: `province.code` goes to `STATE_CODE`; null Wave strings go to NULL.

---

## Security

- Customer contact data is PII: HTTPS only, authenticated RAD Server resources, and a PIN/biometric lock in the mobile app.
- Cache as little as practical on the device.
- The Wave token never leaves the server. Don't commit it; keep it in RAD Server config or an untracked file.

---

## Roadmap

1. ~~Create the schema~~ and ~~run the log-trigger smoke test~~ (both done). Next: create `ccCRM.ini` and run the first sync (see below).
2. **Wave sync** as a Delphi unit with a console test project (verify against the 82 records), then wire it into RAD Server.
3. **RAD Server resources**: customers (list/search/get/update own columns), contacts, log (list/add manual), email list, sync trigger.
4. **FMX client**: search, customer detail, tap-to-call/email, notes/log entry, email-list copy.
5. **AD import**: PowerShell `Get-ADGroupMember` per `AD_GROUP` to fill `USER_COUNT`; flag groups without a customer and customers without a group.
6. **Importer for the existing Firebird database** (future).
7. Later, if wanted: documents table, logo handling, actually sending mail.

---

## Applying the schema

Run in order: `schema.sql` (tables + seed rows), then `schema-programmability.sql` (view, procedure, triggers). Neither contains `COMMIT` or a domain, because DBeaver auto-commits and chokes on both. `SET TERM` worked in DBeaver for part 2; if it ever doesn't, remove the `SET TERM` lines and trailing `^` and run each procedure/trigger block on its own with Ctrl+Enter. Create the database with `DEFAULT CHARACTER SET UTF8` (see the header of `schema.sql`).

### Smoke test for the log triggers (passed)

```sql
INSERT INTO CUSTOMER (WAVE_ID, NAME, EMAIL) VALUES ('TEST1', 'Test Co', 'a@example.com');
UPDATE CUSTOMER SET EMAIL = 'b@example.com', STATUS_ID = 1 WHERE WAVE_ID = 'TEST1';
SELECT EVENT_DATE, ENTRY_SOURCE, SUMMARY FROM CUSTOMER_LOG WHERE WAVE_ID = 'TEST1';
```

Expect three rows: `Customer added from Wave`, `Email: a@example.com -> b@example.com`, `Status: (none) -> Active`. Then remove the test data (delete `CUSTOMER_LOG` rows first, then the customer; log rows reference it).

## Configuring and running the sync tool (`ccCRM.ini`)

One settings file, `ccCRM.ini`, is shared by the sync tool and the RAD Server package (loaded by `src/shared/ccCRM.Config.pas`). It is looked up **beside the module that contains the code**: the exe for `ccCRMSync.exe`, the package (`.bpl`/DLL) for RAD Server. It does not use the host process's folder, so it works under EMS/IIS as well. For RAD Server, keep it outside any web-served folder. It is not created automatically, and it is git-ignored because it holds the Wave token and the database password. If the file is missing, the tool stops with "Settings file not found".

1. **Create the file.** Copy `ccCRM.ini.sample` (repo root) next to the built exe and rename it to `ccCRM.ini` (for example `src\sync\Win64\Debug\ccCRM.ini`, or wherever the exe is deployed on the server).
2. **Create a Wave Full Access token.** In the Wave developer portal (developer.waveapps.com), create an application, then generate a *Full Access* token. Paste it after `Token=`. Treat it like a password; it can read (and write) your whole Wave business.
3. **Find the business ID.** Leave `BusinessId=` empty, set the token, then run `ccCRMSync.exe --businesses`. It prints each business name and its ID (tab-separated); paste the ID after `BusinessId=`.
4. **Set the database.** Fill in the `[Database]` section (see the table below).
5. **Try it safely.** `ccCRMSync.exe --dry-run` fetches from Wave and lists the customers without touching the database. Once the count looks right (82), run `ccCRMSync.exe` to sync.

```ini
[Wave]
Token=<full access token>
BusinessId=<id from --businesses>

[Database]
Server=localhost
Port=0
Database=E:\Data\ccCRM.fdb
User=SYSDBA
Password=<password>
VendorLib=
```

| Key | Meaning |
|---|---|
| `[Wave] Token` | Wave Full Access token. Required. |
| `[Wave] BusinessId` | Wave business ID from `--businesses`. Required for sync and `--dry-run`. |
| `[Database] Server` | Firebird host name. **Leave empty only for a local/embedded file path**; use `localhost` for a normal local server install. |
| `[Database] Port` | `0` = Firebird default (3050). |
| `[Database] Database` | Path of the `.fdb` file **as seen by the Firebird server**. |
| `[Database] User` / `Password` | Firebird login. User defaults to `SYSDBA` if omitted. |
| `[Database] VendorLib` | Optional full path to `fbclient.dll`. It must match the exe's bitness (Win32 exe needs a 32-bit client, Win64 a 64-bit one). Leave empty if it is on the PATH or beside the exe. |

Notes:

- Exit code is `0` on success and `1` on any error (the message goes to stderr), so the tool can run from Task Scheduler for a nightly sync.
- The ini values override anything stored in the data module's connection at design time, so the design-time connection can stay as a convenience for the IDE.
- Don't commit or email the ini file. If the token is ever exposed, revoke it in the Wave developer portal and make a new one.

## RAD Server package (`src/server/ccCRMServer.dpk`)

Compiles (Win32 and Win64, Delphi 12) but has **not been run against RAD Server or a database yet**. Contains `ccCRM.Types/Config/WaveClient/Data` from `src/shared` plus `ccCRM.Server.Json` (dataset to JSON) and `ccCRM.Server.Resources` (the endpoints). Settings come from `ccCRM.ini` beside the built `.bpl`; the server forces pooled connections (named FireDAC definition `ccCRMPool`, 25 connections max). One resource instance (and one `TdmccCRM`) is created per request.

| Resource | Methods | Notes |
|---|---|---|
| `customers` | `GET ?q=&type_id=&status_id=`; `GET /{wave_id}`; `PUT /{wave_id}`; `DELETE /{wave_id}` | List searches name, contact, email, phones, AD group, city **and additional contacts**; `type_id=0` / `status_id=0` lists customers with no type / status (unclassified). Detail includes `contacts` and `log`. PUT updates only `type_id`, `status_id`, `ad_group`, `user_count`, `notes`: missing keys keep their value, JSON `null` clears. Returns the updated customer. DELETE only works for customers no longer in Wave (409 otherwise, 404 if unknown) and removes their contacts and log in the same transaction. |
| `contacts` | `POST`; `PUT /{id}`; `DELETE /{id}` | POST body needs `wave_id`; PUT replaces `name`, `email`, `phone`, `job_title`. Returns `{"rows": n}`; 404 if nothing matched. |
| `customerlog` | `POST`; `PUT /{id}`; `DELETE /{id}` | **Manual entries only** (automatic ones are protected by the SQL; they answer 404). POST needs `wave_id` and `summary`; `event_date` (`yyyy-mm-dd`) defaults to today, so back-dating is just a different date. |
| `lookups` | `GET` | `{types:[...], statuses:[...]}` for pickers and the email filter. |
| `emails` | `GET ?type=ABS Cloud&status=Active` | Names from `lookups`, both optional. Returns `{count, bcc, emails}`; `bcc` is `a@x; b@y` ready to paste. |
| `sync` | `POST` | Fetches from Wave and syncs now; returns `{fetched, added, updated, marked_missing}`. |

JSON keys are the lower-case column names (`wave_id`, `user_count`, `type_name`, ...). Dates are ISO 8601.

Things to know before deploying:

- **Security is configured in RAD Server, not in this code.** Use the RAD Server Console to restrict these resources (for example to your own user/group) and keep the application id/secret private. Until then treat the endpoints as unprotected.
- **Bitness must match the EMS server** (Win32 vs Win64), and so must `fbclient.dll` (`VendorLib` in the ini if needed).
- Register the built `.bpl` in the EMS server's `emsserver.ini` (`[Server.Packages]`) and put `ccCRM.ini` next to it (outside any web-served folder).
- The `{wave_id}` path segment is the Wave id as is. These ids are base64 text without `/` or `+`, so they are URL-safe; an `=` suffix, if any, is fine.
- Untested paths: pooling (`EnsurePoolDef`), `PUT customers` (copies current values through `Variant`), and every resource against real data.

## Mobile app (`src/mobile/ccCRMApp.dpr`)

FMX app (Delphi 12) built on **TFrameStand** (`E:\Delphi\lib\TFrameStand`, add its `source` folder to the library path for each platform). The main form holds a `TFrameStand`; the customer list is the permanent base page, and every other screen is a frame stood on top of it and closed with Back (toolbar button or the Android back key). The app only talks to the RAD Server package; it never touches Wave or the database directly.

| Frame | Does |
|---|---|
| `Customers` | Search (name, email, phones, city, AD group, extra contacts), type and status filters. Searches wait for a pause in typing. |
| `Detail` | One scrolling list: contact info (tap an email or phone to open the mail or dial app), account (type, status, users, AD group), notes, extra people, the dated log. Toolbar: Edit, + Log. |
| `Edit` | Your own columns only: type, status, AD group, user count, notes. Name, email, phone and address stay in Wave. |
| `Log` | Adds a manual log entry; the date defaults to today and can be set earlier to record history. |
| `Emails` | Email list for a type/status (defaults to Active ABS Cloud). Copy the BCC list or hand it to the email app. |
| `Settings` | Server base URL, RAD Server application id and secret (stored in the app's private `ccCRM.ini`), Test connection, and "Sync customers from Wave now". |

Code layout: `ccCRM.App.Types` (records + JSON readers), `ccCRM.App.Api` (blocking REST client, settings, and `TAsync.Run<T>` that runs a call on a pool thread and answers on the UI thread unless the frame has been closed), `ccCRM.App.Platform` (open `tel:`/`mailto:`, clipboard), one `ccCRM.App.Frame.*` unit per frame, `ccCRM.App.Main`.

Status: compiles for Win32 and every frame streams from its `.fmx` (checked headless). **Not yet run against the server, and the Android/iOS branches of `ccCRM.App.Platform` could not be compiled here (no Android SDK libraries installed on this machine).** To do on your side:

- Open `ccCRMApp.dpr` in RAD Studio, add the Android (and/or iOS) target, and enable **Internet** under Project Options > Uses Permissions.
- Use an **https** server address on Android: cleartext http is blocked by default on current Android versions.
- Not built yet: adding/editing/deleting extra contacts, editing or deleting a manual log entry, user login (the app currently authenticates with the RAD Server application id/secret only), and the lock/biometric screen.

## Open items

- **Default status/type for new Wave customers**: currently NULL (unclassified).
- **Later AD import**: confirm that each customer's AD group name is consistent enough to fill `AD_GROUP` once by hand.
- **Prospects**: explicitly out of scope. If that changes, `WAVE_ID` would need to become nullable with a separate surrogate key.

## Files

- `schema.sql`: Firebird 5 tables, indexes and lookup seed data (applied).
- `schema-programmability.sql`: `V_EMAIL_LIST` view, `LOG_CHANGE` procedure, log triggers, sync upsert example (applied).
- `src/sync/ccCRMSync.dpr`: console app (`--businesses`, `--dry-run`, or sync). Open the `.dpr` in RAD Studio 12 to create the `.dproj`. Settings in `ccCRM.ini` next to the exe (copy `ccCRM.ini.sample` from the repo root; git-ignored, holds the token).
- `src/shared/ccCRM.Config.pas`: `TccCRMConfig.Load` reads `ccCRM.ini` (Wave token/business, database settings); shared by the sync tool and the RAD Server package.
- `src/shared/ccCRM.Types.pas`: records and config shared by everything (no UI/DB dependencies).
- `src/shared/ccCRM.WaveClient.pas`: read-only Wave GraphQL client (`THTTPClient`; `ListBusinesses`, `FetchCustomers` with paging). Package-safe.
- `src/shared/ccCRM.Data.pas/.dfm`: `TdmccCRM` data module: Firebird connection, `Connect(config)`, `SyncCustomers(array)`, `OnLog`. Used by the console app and the RAD Server package; REST datasets/queries get added here next. All SQL lives in design-time components (`qWaveIds`, `qCount`, `cmdUpsert`, `cmdMarkMissing`).

### Code conventions

- Use inline variables (`var X := ...`, `for var C in ...`) wherever possible.
- Put SQL in design-time components (TFDQuery etc. on the data module) instead of string constants, to keep code small.
- `src/server/`: the RAD Server package `ccCRMServer.dpk` (`ccCRM.Server.Json.pas`, `ccCRM.Server.Resources.pas`). See the RAD Server section above.
- `src/mobile/`: the FMX mobile app (`ccCRMApp.dpr`, `ccCRM.App.*`). See the Mobile app section above.
- `wave-customers.graphql`: GraphQL queries for listing businesses and customers (not yet run).
- `README.md`: this file.
