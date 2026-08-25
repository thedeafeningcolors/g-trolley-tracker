# Session log

Newest entry first. The plan and its short progress log live in `docs/APP-STORE-PLAN.md`; store copy in `docs/APP-STORE-LISTING.md`.

## 2026-08-25: health check, and the day-detail timezone fix

### Work completed

- Full health check after Cris saw only one trolley on a clear weekday. Verdict: no tracker bug. SEPTA itself had zero PCC cars out; the feed showed 19 G1 blocks with 9 real vehicles, all buses, and the tracker matched it exactly.
- The one trolley was verified real: car 2324 appeared at 9:35 AM ET for a single 5-minute sample, and the daily push alert fired at 9:35:13 AM to 4 phones. The collector was current within one minute at check time.
- Context pulled from the tracker's own history: Monday 8/24 had zero PCC observations all day, while the previous three Tuesdays had 4 to 6 cars and 30 to 43 trips. SEPTA has posted no alert, detour, or suspension for Route 15. Bus substitution is the inference; transponders could also simply be off.
- Found and fixed a real bug the check surfaced: `pcc-day-detail.js` showed per-vehicle times 4 hours early (2324 read 5:35 AM instead of 9:35 AM). Root cause: the code re-parsed `toLocaleString` output into a second Date, so the Eastern zone was applied twice. Also fixed the day-boundary query, which had winter time (-05:00) hardcoded year-round.
- Fix tested under a UTC clock like Netlify's, deployed by git push per the standing rule, and verified live with a cache-busting request. Commit `20f2d3d`.

### Where this falls in the plan

- Post-launch watch duty: this was the "watch the first real alerts" item working as intended. The alert pipeline, collector, and endpoints all proved healthy under a real anomaly.
- The trolley drought itself is SEPTA's operational choice and outside the project's control.

### Roadblocks and challenges

- One failed push recipient in the morning alert (4 delivered, 1 failed). The sender disables tokens dead in both environments, so this self-heals by design.
- The Netlify CLI still links this folder to the wrong project (`sjta-shuttle`); the site ID must be passed explicitly, as noted in memory on 2026-08-16.

### Successes and new understandings

- The two endpoints disagreed on the same timestamp (9:35 AM in pcc-stats, 5:35 AM in pcc-day-detail), and that disagreement was the thread that unraveled the bug. Cross-checking endpoints against each other is a cheap audit.
- Server-function fixes reach the iPhone app instantly: the app bundles the UI files but calls the live Netlify functions for all data, so no App Store build was needed. UI-file changes still require a new build through review.
- The pattern to avoid, now documented in the code: never build a Date from `toLocaleString` output and then format it with a timezone again. Use Intl to derive Eastern hours from the real UTC instant.

### Pick up next session

1. Watch whether PCC cars return to the G1; if the drought stretches on, the tracker's history is the evidence, and nothing needs fixing.
2. Re-run the device search backend queries ("pcc trolley", "septa trolley") if not yet done 48 hours after release; the keyword field is the lever if still empty.
3. Confirm the fiancee's phone can reach the listing, still the last unclosed launch thread.
4. Keep watching push-status and Netlify credits.
5. Banked ideas remain: whole-line vertical live view, new-trolley-in-service alert, Google Play.

## 2026-08-19 to 2026-08-20: released, and the launch-day outage

### Work completed

- Version 1.0 released manually in App Store Connect at 12:34 PM ET on 2026-08-19. Approved on build 4, priced $4.99, United States only.
- Website promo gate fixed. The "Get the app" button queried Apple with `country=us` (lowercase), which returned 0 results for hours while `country=US` returned the record. A control app (WhatsApp) answered on both, so the casing was specific to a freshly released record, not a general API rule. Dated note added in `app.js` so it is not changed back.
- Launch-day outage found and fixed. Every Supabase-backed function returned HTTP 502, `Cannot find module '@supabase/supabase-js'`: push-subscription, push-stop-alert, push-status, pcc-stats, log-visit. Cause: a `netlify deploy --prod --dir .` from a working tree with no `node_modules`, which landed on top of a good git build. `netlify.toml` marks Supabase external, so the CLI shipped the functions without it. Fixed with `npm install` and a redeploy.
- Deploy rule written into `README.md` with a four-line health check, and saved to auto-memory. Deploys go through a push to `main` from now on, because the connected Netlify build runs `npm install`.
- Cris bought the app himself and confirmed the purchase path, the download, and alert saving after the fix.

### Where this falls in the plan

- The App Store phase is finished: scoping, shell, native features, listing, submission, approval, release. The app is on sale.
- What remains is post-launch: search visibility, first real users, and the banked ideas (whole-line vertical live view, new-trolley-in-service alert, Google Play).

### Roadblocks and challenges

- Roughly five hours of "not available in your region" on Cris's iPhone while every server-side check said the app was live. App Store Connect read READY_FOR_DISTRIBUTION, the US territory read `available: true` and `AVAILABLE`, the web page returned 200, all six screenshots returned 200, and the buy offer was intact. Apple propagates per device and per account, and no setting was ever wrong.
- Two wrong calls made along the way, both corrected with evidence in the same session. First, "cannot connect" was blamed on the home network; Cris pointed out every other listing loaded instantly, which killed it. Second, the app was reported at position 4 for "philly trolleys" and Cris was told to scroll; the public iTunes Search API had it at 4, but the device search backend did not have it at all. Two different indexes.
- The outage was self-inflicted and hit on the day the app went on sale. The CLI deploy that broke it was made to ship the promo-gate fix.
- The only symptom that pointed anywhere useful was Cris noticing that a misspelling ("philly trollehs") surfaced the app while the correct spelling did not.

### Successes and new understandings

- The storefront endpoint iPhones actually query can be reached from the terminal: `itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=<id>` and `search.itunes.apple.com/WebObjects/MZStore.woa/wa/search?...`, both with `X-Apple-Store-Front: 143441-1,29` and an `AppStore/3.0 iOS/17.0` user agent. That is the difference between guessing about a device and reading what the device reads.
- The public `itunes.apple.com/lookup` and `/search` APIs are a different index from device search. A record can sit in one and not the other for hours. Never report device behavior from the public API alone.
- A misspelled query bypasses the ranked search index and falls back to a catalog lookup, so it can surface an app that search cannot find. That is a usable diagnostic for whether an app is indexed or merely present.
- The EU trader disclosure only governs EU storefronts. It explains `TRADER_STATUS_NOT_PROVIDED` and `CANNOT_SELL` on the European territories and has no bearing on the United States.
- Search indexing landed about 7 hours after release. Verified 2026-08-20: "philly trolleys" and "philly trolley" both return the app at position 8 of 8; "pcc trolley" and "septa trolley" do not return it.

### Pick up next session

1. Re-run the four searches ("philly trolleys", "philly trolley", "pcc trolley", "septa trolley") against the device search backend. If the SEPTA and PCC terms are still empty 48 hours after release, the keyword field is the lever and the change should be drafted with the search evidence attached.
2. Confirm the fiancee's phone can reach the listing, which is the last unclosed thread from launch day.
3. Watch the first real alerts go out to paying users, and check push-status and Netlify credits.
4. Then pick up the banked ideas: whole-line vertical live view, new-trolley-in-service alert, Google Play.

## 2026-08-17: Apple asked for more information

### Work completed

- Apple's reply (11:54 PM on 2026-08-16) was Guideline 2.1, Information Needed: a physical-device screen recording plus seven written answers. Not a rule violation.
- Drafted the full reply in `docs/APP-REVIEW-REPLY.md`: a recording shot list for Cris's iPhone 15 Pro (iOS 26.6, checked with devicectl) and the answer text (devices, description, setup, external services, regions, third-party material). Listing doc's review notes now point there, with a short version for the Notes field.
- Checked live status at 6:38 AM: PCC cars 2332 and 2337 out, so the recording can be made any time today during service.

- Bug found by Cris before recording: Route Options showed "#block_9013_schedBasedVehicle to arrive at 7:33 AM". Root cause (verified against SEPTA's TransitView and TransitViewAll): SEPTA publishes a placeholder "vehicle" named block_NNNN_schedBasedVehicle for a scheduled trip with no live vehicle; 1 of 10 G1 entries at 6:38 AM, 7 system-wide at 6:52 AM. The other lines already filtered these; the G1 loop did not. This is also the "over-long vehicle id" the tracker had been rejecting since 2026-08-16. Fixed in the app, tracker, and widget feed; website live and verified; build 3 archived and exported (IPA at native/ios/App/build/export3), upload waiting on Cris.

- Build 3 uploaded by Cris (API key; the Xcode-account upload path fails on this Mac with "team IDs for account (null)"). Issuer ID now saved in ~/.appstoreconnect/issuer_id, so `scripts/asc.py` (dependency-free API client) works from any session.
- Widget refresh button (banked post-launch item, pulled forward): the "Updated h:mm" line on the small and medium widgets is now an interactive AppIntent button that reloads the timeline; the count shimmers while it reloads. Verified on the Pro Max Simulator: one tap took the widget from 4 cars at 7:08 to 5 cars at 7:10 without opening the app. Build 4 archived and exported.
- Decided: resubmit with build 4 rather than reply on build 2. Staging scripts written (`scripts/asc_stage.py`, `scripts/asc_submit.py`) because the assistant is blocked from Apple-side writes; Cris runs them with `!`. Version 1.0 is REJECTED / submission UNRESOLVED_ISSUES, so the build and notes are editable.

- Resubmitted 2026-08-17, 7:59 AM ET: submission 796656fe, WAITING_FOR_REVIEW, version 1.0 with build 4, notes written, 4:37 screen recording attached (phone recording re-encoded from 399 MB to 40 MB at full resolution with `scripts/reencode-video.py`; verified frame readable). Cris ran every Apple-side write with `!` (upload, stage, attach, submit); the assistant is blocked from those. The first submit attempt hit a transient "not in valid state" right after cancelling the old submission; the second attempt, reusing the fresh submission, went through.

### Where this falls in the plan

- Done except Apple's decision. Second time in the queue.

- Banked two ideas from Cris for after approval (plan file, backlog items 5 and 6): a collapsed whole-line live view (vertical strip, west at top, pulsing green dots with direction arrows) and a "new trolley in service" alert.

### Roadblocks and challenges

- The App Store Connect API has no endpoint for replying to App Review messages, so the round became a resubmission with the answers in the notes and the recording as an attachment.
- The API key's Issuer ID was not on disk (only the .p8); Cris pasted it from App Store Connect and it now lives in ~/.appstoreconnect/issuer_id.
- Every write to Apple (upload, PATCH, POST) is blocked for the assistant by the permission classifier; reads work. Cris ran each write as a one-line `!` command. Multi-line pastes split in his shell twice (a bare `xcodebuild` ran once, a video path with spaces broke once), so commands must be one line with no spaces in paths.
- The Xcode-account upload path fails on this Mac ("team IDs for account (null)"); the API key path works.
- avconvert's presets barely shrank the 399 MB recording (416 MB at 1080, 271 MB at 720); a 2.5 Mbps AVFoundation re-encode at full resolution gave 40 MB (`scripts/reencode-video.py`, needs pyobjc-framework-AVFoundation).
- Cris's airplane-mode test did not go offline because Wi-Fi stayed on; offline mode was skipped in the video, which Apple did not ask for anyway.

### Successes and new understandings

- SEPTA's schedule-based placeholder vehicles (block_NNNN_schedBasedVehicle) explain both the ugly Route Options entry and the tracker's over-long-ID rejects; one filter fixes all readers.
- Interactive widget buttons (AppIntent, iOS 17) work in a Capacitor project with no app-side code; the "Updated" line as the tap target keeps the layout intact, and Cris confirmed the refresh on his real phone.
- The whole resubmission (notes, build swap, attachment upload in 8 chunks, new review submission) can be driven by the API from a dependency-free Python client (openssl for the ES256 signature, curl for HTTP, `-g` to keep square brackets literal).
- Swapping the build moved the version from REJECTED to PREPARE_FOR_SUBMISSION; a submission in UNRESOLVED_ISSUES cannot take new items, so cancel it and open a fresh one, then add the version and submit.

### Where to pick up next session

1. Apple's decision. Approved: "release" (API or the Release button). Anything else: paste it here.
2. After launch: watch push-status and Netlify credits; the post-launch backlog in the plan file; Google Play stays banked.

## 2026-08-16 (evening): research session, no code

### Work completed

- Researched the Alstom Citadis timeline, PCC fleet status, SEPTA vehicle numbering and API fields, and Manayunk transit history for the app's next phase. Findings and the ordered backlog are in `docs/APP-STORE-PLAN.md` under "Post-launch backlog".
- Verified the 23xx PCC rule against the tracker's own data (all 8 logged PCC IDs are inside 2320 to 2337, no bus prefix starts with 2) and against a live scan of every SEPTA vehicle (one ID starting with 2 system-wide, PCC 2333).
- Traced the 41 "9xxx" IDs logged as buses on G1: Route 10 K-cars from Callowhill tagged G1 on pull-outs along 59th St and Girard to the Lancaster junction, plus one real end-to-end G run by 9039 and 9082 on Feb 23, 2026. Confirmed with GTFS block IDs (G1 blocks 9001 to 9026, T1 9051 to 9069) that these are car numbers, not blocks. Special trips not logged into blocks (K-car 9000 retirement trip on Girard, March 15, 2026, photo found by Cris) do not appear in the feed.
- Memory and plan file updated. Apple review still pending; no app or site changes this session.

### Where this falls in the plan

- The launch plan is complete except for Apple's decision. This session shaped what comes after launch: the app's runway on the G is longer than feared (Citadis reach the G last, in the 2030s), and the mixed-fleet period arrives first on the T and D lines, so the expansion path is the per-line "what's running" view built on the tracker's existing feed pull.

### Roadblocks and challenges

- The Supabase service key is a masked Netlify secret, so the CLI cannot read tables; Cris ran the queries in the SQL editor and pasted results.
- The session's web search budget ran out partway through (four research agents), so later checks used direct fetches and SEPTA's GTFS and live feed instead.
- Two false leads on the 9xxx IDs (placeholder rows, then block numbers) before GTFS block ranges and coordinates settled it.

### Successes and new understandings

- SEPTA's own vehicles page now dates Citadis delivery and deployment to 2030 to 2034 (was 2027 to 2032 until at least February 2026); order of lines is T, D, then G.
- No SEPTA feed field states vehicle type; ID ranges are disjoint and reliable, and the 23xx PCC rule is verified against seven months of data and a live system-wide scan.
- The 9xxx IDs on G1 are Route 10 K-cars crossing G track on Callowhill pull-outs, plus one real G run on Feb 23, 2026. Special trips outside a block do not appear in the feed.
- The Venice Island track is the Reading's Venice Branch, standard gauge, so the heritage line idea is parked as advocacy, not app work.

### Where to pick up next session

- Apple review result first. Then the backlog in the plan file, in order (classification table with a kcar bucket, tracker widened to all trolley routes, "what's running on my line" screen, K-car-on-Girard alert).
- Supabase queries were run by Cris in the SQL editor; the service key is a masked Netlify secret, so the CLI cannot read the tables. If a future session needs raw table access, ask Cris to run the query.

## 2026-08-16: submitted to Apple

### Work completed

- Apple developer account activated; APNs key, App ID with push, Netlify settings, App Store Connect API key (App Manager) all in place. Team ID 7QZM9CC55X, App Store Apple ID 6802036569.
- Alerts, end to end: first of the day, each new car, and stop alerts (several saved stops per phone, direction, distance); wording per Cris; verified with real pushes to the Simulator and to Cris's iPhone, on sandbox and production paths.
- App: redesigned alerts card, About page, support contact form (Netlify Forms), new logo, lock screen widgets, share button, widgets that refresh when an alert lands, offline mode, safe-area fixes, Title Case headings, "PCC Trolleys" capitalization, no-orphans pass.
- Website: promo strip for the iPhone app ($4.99 one time, no subscription) that reveals itself when the store listing goes live; Smart App Banner; safe-area padding for the home screen version.
- Store: seven 6.9-inch screenshots with three live trolleys; listing text, categories, subtitle, privacy URL, age rating 4+, price, US-only availability, copyright, manual release, review contact and notes, all set through the API. Build 1 then build 2 uploaded (Xcode-account signing plus altool with the API key). Cris tested build 1 through TestFlight on his phone.
- Submitted: version 1.0, build 2, Waiting for Review since 2:34 PM ET. Release is manual.

### Where this falls in the plan

- Every phase of the plan is done except Apple's decision and the release. Google Play stays banked.

### Roadblocks and challenges

- Netlify keeps an unchanged function bundle across deploys, so the tracker ignored the new APNs settings until its file changed; the morning's first-of-day alert was missed for that reason. Same again for APNS_SANDBOX: force a bundle change after any env change.
- Netlify CLI links the home folder to the personal site; always pass NETLIFY_SITE_ID. A value beginning with dashes cannot be passed to env:set; the .p8 went in base64.
- The App Manager API key cannot create distribution certificates; sign with the Xcode login, upload with the key.
- Internal TestFlight testers cannot be added by API; Cris added himself in the UI.
- Simulator taps land only when the Simulator is frontmost, and its window moves; re-read the AXGroup position before tapping. Momentum scrolls need a slow drag with a hold.
- pcc_observations.vehicle_id is varchar(10); some run rejects a batch. The tracker now retries row by row and logs the culprit; the culprit had not appeared in the log by end of day.

### Successes and new understandings

- The whole App Store Connect setup can be driven by API in one sitting: localizations, app info, age rating (new 2026 fields), price schedules with ${local} ids, availability needs all 175 territories, screenshot upload flow, review submission.
- The Simulator issues real device tokens; with the production-first-then-sandbox fallback, one server setting serves Xcode, TestFlight, and App Store installs.
- content-available on visible pushes plus a background mode lets the app refresh widgets the moment an alert arrives.

### Where to pick up next session

1. Apple's review email. Approved: "release" (API or the Release button). Rejected: paste the reason, fix, resubmit.
2. First update after approval: tap-to-refresh icon on the home screen widget; check the tracker log for the over-long vehicle id.
3. After launch: watch push-status and Netlify credits; consider Google Play.

## 2026-08-15 to 2026-08-16: from web app to App Store candidate

### Work completed

- Scoped the App Store move: research on SEPTA data terms and trademarks, Apple review rules, fees, tooling. Written up in `docs/APP-STORE-PLAN.md`.
- Banked decisions: website stays free, iPhone app is $4.99 pay once, name "Philly Trolleys" (matches the logo Cris drew), bundle ID `com.cristoferslotoroff.phillytrolleys`, iPhone-only, US only at launch.
- Built the Capacitor shell in `native/`. Same web files serve the site and the app; `IS_NATIVE` in `app.js` swaps the header, hides the coffee link, skips visit logging, and points function calls at the live site.
- New logo installed as app icon (text-free crop), splash, and in-app header. Icon and splash generated from `Graphics/philly-trolleys-logo.png`.
- Push alerts: Trolley Alerts card with an opt-in toggle, Capacitor push plugin, AppDelegate hooks, entitlement. Server side sends straight to Apple over HTTP/2 (`netlify/lib/apns.js`), one alert per Philadelphia day when the first PCC appears, claimed in `push_alerts_sent` to prevent duplicates. Supabase tables created by Cris. Verified on the Simulator: permission prompt, token issued, token saved.
- Home screen widget "PCC Trolleys Now" (small and medium), fed by `/.netlify/functions/widget-status`, refreshes every 15 minutes and on app open. Extension target added by script (xcodeproj gem). Verified live on the Simulator home screen.
- Offline mode: last trolley list and analytics saved locally and shown with their time when there is no connection. `?offline=1` simulates no network on the web preview.
- Website improvements shipped live: "Not affiliated with SEPTA" footer, privacy and support pages, 404 page, 404 rules for internal folders, analytics auto-retry with a Try again button, all stray dashes removed, no-orphans pass (pretty and balanced wrapping, tiles and buttons that fill rows, phone step text wraps instead of clipping, line buttons two per row on phones, roster 8 per desktop row and 4 per phone row).
- Store listing copy drafted in `docs/APP-STORE-LISTING.md`: name, subtitle, description, keywords, URLs, privacy label answers, review notes, screenshot plan.

### Where this falls in the plan

- Phases done: scoping, shell, native features (alerts, widget, offline), listing copy.
- Phases left: Apple account activation (pending), APNs key and Netlify env vars, Xcode signing team, store screenshots during service hours, TestFlight on Cris's phone, submission. Google Play is banked for later.

### Roadblocks and challenges

- Credentials are off limits to the assistant (Netlify env, Supabase), so Cris ran the SQL by pasting; the first attempt pasted the file name instead of its contents.
- Xcode was not installed at the start; `xcode-select` still points at CommandLineTools, so every build uses `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Simulator builds with signing disabled strip the push entitlement; ad-hoc signing (`CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO`) keeps it.
- Scripted taps needed Accessibility access; long presses needed a Quartz CGEvent helper (`pyobjc-framework-Quartz`).
- A pre-existing phone-width bug clipped route step text mid-word; fixed as part of the orphans pass.

### Successes and new understandings

- The whole app can be built, installed, launched, tapped, scrolled, and screenshotted from the terminal: `xcodebuild` plus `simctl`, System Events clicks at `{1073 + x_pt, 119 + y_pt}` for the iPhone 17 Pro window, PageDown (key code 121) to scroll the web view, and the Quartz helper for long press and drag.
- The Simulator issues real APNs device tokens on Apple silicon, so the alert flow could be verified end to end short of delivery.
- Apple's sandbox answered the HTTP/2 push probe in 133 ms with the expected 403 for a fake key, so the sender is known good before the real key arrives.
- `text-wrap` is inherited, so one rule on `body` covers runtime-built text; `balance` on short blocks is what actually removes two-word last lines.

### Late addition, 2026-08-16

- Apple enrollment cleared. APNs key made, Netlify variables set (base64 key, trolley site by ID), App ID registered with push. A real test alert reached the Simulator through Apple's servers. Team ID recorded in the Xcode project.
- Lesson: `~/.netlify/state.json` links the home folder to the personal site; always pass `NETLIFY_SITE_ID`. And a value that starts with dashes must be base64-encoded for `netlify env:set`.

### 2026-08-16, afternoon (autonomous stretch while Cris was out)

- Store screenshots captured with three live trolleys on the iPhone 17 Pro Max Simulator (docs/store-screenshots).
- Build 1 archived, exported with Xcode-account signing, uploaded with altool and an App Store Connect API key (App Manager keys cannot create distribution certificates, so signing and upload are separate steps).
- App Store Connect filled through the API: text, categories, subtitle, privacy URL, age rating, $4.99 US price, US-only availability, copyright, manual release, content rights, screenshots, review notes drafted (phone number still needed), build attached to 1.0, internal TestFlight group created.
- APNs sender now tries production first and falls back to sandbox per token; tokens dead in both are disabled. Verified with a 3-phone test send.
- Redesigned alerts card (master switch, three checkboxes, several saved stops), alert wording per Cris, share button with the App Store link, About page, support form via Netlify Forms, new logo everywhere, lock screen widgets, safe-area fix on the site.

### Submitted

- 2026-08-16, 2:34 PM ET: version 1.0 (build 2, widgets refresh on alerts) submitted for App Review through the API. TestFlight verified on Cris's iPhone, including a real alert through the production path. Manual release after approval.

### Pick up next session

1. Watch for Apple's review result (email). Approved: say "release". Rejected: paste the reason.
2. Sign in to Xcode with the Apple ID once (Xcode, Settings, Accounts) so signing and TestFlight work.
2. Capture 6.9-inch store screenshots on the iPhone 17 Pro Max Simulator on a weekday between 10am and 4pm Eastern, when PCC cars are out (list in `docs/APP-STORE-LISTING.md`).
3. TestFlight build to Cris's phone, confirm a real alert arrives, then submit.
