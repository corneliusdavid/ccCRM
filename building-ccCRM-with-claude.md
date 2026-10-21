# Building ccCRM with Claude Code: a conversation, October 2026

This is a condensed record of a working session between David Cornelius and Claude Code. It started with one open-ended question and ended, about two and a half weeks later, with a working customer database, a REST server and a mobile app.

**How to read this:** the first message is quoted exactly, because it is the whole starting brief. Later messages from David are shortened or paraphrased (quoted fragments are exact). Claude's replies are summarized. Nothing here was invented to make the story tidier; where something was untested or went wrong, it says so.

---

## The starting question (verbatim)

> I want to start a new project, possibly in this folder (web based) but I'm also open to a mobile app. let me explain: I have several ABS Cloud customers that have accounts on remote desktop servers in Azure. I bill them through my accounting system, WaveApps.com, which has an API (`https://developer.waveapps.com/`). I have some customer management built in to the RDWeb pages (see the git log in this folder) and am thinking of tying it with that to link up customer data. My goals are to be able to keep notes for the customers, quickly look up emails and phone numbers, and have a way to generate a list of email address to blast out a message to everyone. As you know, I am a Delphi developer, so am thinking of a mobile app that ties into a server; for the server, I would expand a RAD Server I already have established on one of the ABS Cloud servers and maybe tie that with my WaveApps data instead of adding to the RDWeb pages here. But I also like the idea of tying it together so I don't have two different sets of customers/records to maintain. What are the best ideas out of this?

Notice what that message contains: a goal (notes, lookup, email list), a constraint (don't keep two sets of customer records), an existing asset (a RAD Server), and an honest "what are the best ideas?" rather than a request for specific code. The answer was a design, not a program.

---

## Phase 1: Deciding the design (Oct 4)

**Claude's first answer** proposed four ideas:

1. **One source of truth, split by field.** Wave owns identity and contact data (name, email, phone, address). The new database owns what Wave doesn't have: customer type and status, notes, extra contacts, a history log, AD group, user count. The two are joined on the Wave customer ID.
2. **Put the logic in RAD Server, not in the RDWeb pages.** The Wave token must stay server-side, and the RDWeb pages are inline C# deployed by drag and drop with no data layer.
3. **A Delphi FMX mobile app** for lookup on the road (tap to call, tap to email).
4. **The email blast starts as list generation** (copy a BCC string), not sending. Actually sending mail is a separate project.

Claude asked two questions: where does the existing RDWeb customer data live, and which database does RAD Server use?

**David's answers:** the RDWeb customers come dynamically from Active Directory via PowerShell, with no database. RAD Server uses InterBase, and a Firebird database would be imported later.

**Researching the Wave API.** Wave's developer site returned 403 errors to Claude's fetch tool, so the findings came from search results and third-party write-ups, and Claude said so up front. What it found: GraphQL only; a "Full Access" token is meant for personal or internal use; rate limits are generous for 82 customers; no webhooks, so the sync is polling.

**David pasted a real record** from his Wave account (82 customers, data clean, a mix of current ABS, former ABS and non-ABS customers). The sample showed the fields available, and that the company `name` was missing from the first query. A second sample added it.

**Design refinements over several messages**, driven by David's decisions:

- Type and status become **lookup tables** (editable), not hard-coded values. First three statuses (Current ABS Cloud, Former ABS Cloud, Non-ABS), then, after David decided to replace his current CRM, two separate fields: **Type** (ABS, ABS Cloud, Retail Pro) and **Status** (Active, Inactive).
- No separate "extension" table: extra columns go straight into the customer table.
- A **user count** per customer (manual now, imported from AD later), and a **one-to-one AD group** per customer, stored in the customer table.
- A **contact table** for extra people, with the main contact staying in the customer table.
- A **log table**: automatic entries written by database triggers when fields change, plus **manual entries with an editable, back-datable date**, so old history ("customer signed up 04-29-2020") can be typed in.
- **Rules:** Wave data is never deleted or written to by the app; a customer who disappears from Wave is flagged, never removed; no prospect tracking ("Once they're with me, they're a billable customer").

The project name changed along the way: first `MyCRM` in `E:\Delphi\MyCRM`, later renamed **ccCRM** in `E:\Delphi\ccCRM`, with `src\server` (RAD Server package) and `src\mobile` (the FMX app) as separate subfolders.

---

## Phase 2: The database (Oct 4 to Oct 11)

- Claude wrote the schema as SQL, then rewrote it when David switched from InterBase to **Firebird 5** (Claude recommended 5 over 4: longest support window, and nothing in the schema needed a Firebird 4 feature).
- Running it in DBeaver produced errors from `COMMIT` statements and `CREATE DOMAIN`. Both were removed, the script was split into two files (tables first, then view/procedure/triggers), and David confirmed 5 tables, 1 view, 1 procedure, 2 triggers and 4 identity sequences.
- A **smoke test** of the log triggers (insert a customer, change the email and status, read the log) passed on the first run. David deleted the test rows.

## Phase 3: The sync tool (Oct 11)

David asked for a **Delphi 12 data module and a console app**, designed so the data module could later move into the RAD Server package.

What was built, and the rules David added as he went:

- A data module with the Firebird connection and the sync logic, a read-only Wave GraphQL client, and a shared settings file.
- "Use **inline variables** as much as possible" and "put **SQL in components at design time**." Claude rewrote everything to that style and saved the preference to its memory so later sessions would follow it.
- A single `ccCRM.ini` shared by the sync tool and (later) the RAD Server package, read from beside whichever module contains the code.
- Claude compiled with the Delphi 12 compiler and tested the data module's design-time file by loading it without a database. It could not test against a real Wave account or database.

**First real run:** HTTP 404, `Cannot POST /graphql`. The endpoint Claude had written into the code was wrong. Claude had not verified it, and said so. A probe with no credentials showed the correct address (`/graphql/public`), and after the fix **82 customers loaded**.

## Phase 4: The RAD Server package (Oct 11)

- Claude read the RAD Server source on the machine to get the attribute and signature details right, then wrote resources for customers, contacts, the customer log, lookups, the email list, and "sync now," with FireDAC connection pooling.
- It compiled for Win32 and Win64. It could not run against a RAD Server.

**Deployment problems, and what they turned out to be:**

| Symptom | What Claude first suggested | Actual cause |
|---|---|---|
| "Socket error #10013" when starting the dev server | Port 3050 clash between InterBase and Firebird, firewall, IPv6, wrong client library | After David corrected the facts (the package loaded fine in IIS; the error came from EMSDevServer starting), Claude pointed at the dev server's own listener port. David: **another service already used port 8080.** |
| 404 in IIS | Wrong resource name, or a package/bitness mismatch | Resolved together with the above; the package worked once the dev server moved to port 8081. |

The honest lesson, for the presentation: the first diagnosis (a database port clash) was wrong, and the right answer only appeared when David gave a more accurate description of what he saw.

## Phase 5: The mobile app (Oct 11 onward)

David asked for the app to use **TFrameStand**, "like we have in other mobile projects."

- Claude searched the machine and found the TFrameStand library and one of David's projects that uses it. It found that another project David named (county-quizzer) did not use TFrameStand or a server at all, and said so rather than pretending to follow a pattern that wasn't there.
- It built the app: a customer list with search and filters, a detail screen (tap an email or phone to open the mail or dial app), an edit screen, a log screen, an email-list screen, and a settings screen. It compiled for Windows and loaded every screen headless. The Android and iOS code could not be compiled on that machine.

**Bugs found by testing it, in order:**

1. **Blank Application ID.** RAD Server allows one; Claude's code insisted on one. Fixed.
2. **Encrypting the ID/secret.** David suggested it. Claude explained that on a phone, a key stored next to the encrypted value only obfuscates it, and that real protection needs the platform keychain. It did not claim a false fix.
3. **Settings file location.** Fixed: beside the exe on Windows, in the app's private folder on phones, with a warning never to copy the server's ini (which holds the Wave token and database password) to a phone.
4. **A startup race.** The list started loading on a background thread before the settings were loaded, so the first request failed with "enter the server address" and the second worked. Fixed by loading settings once at program start.
5. **Layout.** Three requests: make the list fill the window, open a customer only from a button, and fix dropdowns overlapping the labels above. Rather than guess, Claude **measured the actual control positions at runtime** and found the combo boxes were drawn 50 px tall while the layout reserved 36. Fixed, and re-measured: zero overlaps.

---

## Things worth saying out loud in a presentation

- **It started as a design conversation, not a code request.** The most useful early work was deciding which system owns which data.
- **Claude could check its own work only partly.** It compiled everything with the real Delphi 12 compiler, loaded forms headless, and measured layouts, but it could not reach the user's Wave account, database, server or phone. Every "it works" in this story happened on David's machines.
- **Mistakes happened and were reported plainly:** an unverified API address, a first diagnosis that pointed at the wrong port, a missing blank-ID case, a startup race. Each was found by running the thing.
- **The user steered throughout:** the move from InterBase to Firebird, the replacement of an existing CRM, the coding-style rules, and corrections to Claude's assumptions.
- **Where it stands:** a Firebird database holding 82 customers synced from Wave, a RAD Server package serving them as JSON, and a mobile app listing, viewing and editing them. Open items at the time of the last build: Android/iOS compiling, per-user login, and securing the RAD Server endpoints in its console. The app's source has continued to grow since this record was written (for example contact editing and icons appeared in the project files); this document covers the conversation up to the layout fixes.
