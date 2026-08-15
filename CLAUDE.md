# Truck Management System — Master Build Spec (Final)

**Authority:** This document supersedes all earlier prompts. Where conflicts exist with previous auth, trip, or feature specs — this wins. Do not resurrect anything this explicitly overrides.

## Key Overrides from Earlier Sessions

1. **Auth**: Driver registration **does not exist as a public flow**. Only Owner self-registers. Drivers created solely via Owner `POST /drivers` endpoint with temp password.
2. **Flutter Driver**: No registration screen. "Set New Password" screen shown on first login when `mustChangePassword: true`.
3. **Flutter Owner**: Add Driver form (name, phone, email?, license number?) → temp password display/share → drivers list with deactivate/reactivate actions.
4. **Trip status vs. Duty status are separate.** Trip status = per-trip lifecycle (assigned → in-transit → delivered/failed). Duty status = Online/Offline, independent of any single trip, controls all-day location tracking.
5. **Location tracking is Duty-status-driven, not trip-status-driven.** While Online, ping every 60s regardless of whether a trip is active. While Offline, no tracking, period.
6. **Trip expenses are never locked by delivery status** — only by Owner-set `financiallyClosed` flag. Drivers can log/edit fuel, fines, and other expenses live, right after a trip ends, or in a batch "Catch Up" pass covering any date's unclosed trips.
7. **"Park" tab = Orders module** (sales/order log), not a physical yard concept, unless corrected later. Columns: date, customer name, item, CFT, amount, payment mode (Cash/UPI/Bank Transfer/Credit).
8. **Financial reporting is consolidated into a single multi-sheet Excel workbook per period** (Daily / Monthly / Six-Month) — sales, expenses, driver expenses, and credit all in one file, not scattered exports.
9. **Live tracking map uses `flutter_map` + OpenStreetMap**, not Google Maps, to guarantee $0 cost.
10. **Quarterly reporting is deferred**, not built — period resolver must still be structured so it's a one-line addition later.
11. **Flutter Driver home screen redesign (supersedes Step 6/7 UI as built)**: the slide-to-start/end control and the expense list/entry no longer live inline on the "My Trips" list. Home screen shows completed trips plus the current assigned/in-progress trip as a single tappable card — the card itself is tap-to-open, not inline-actionable. Tapping it opens a **Trip Detail** screen that consolidates: the slide-to-start/end control (pinned to the bottom of the screen), this trip's expense list, and an "Add Expense" button. Completed trips are tappable too (same Trip Detail screen, no slide control) so a driver can still add/edit expenses after delivery — expenses lock on `financiallyClosed`, not delivery status. Implemented 2026-08-09.
12. **Double-booking guard removed (reverses the original Trip Assignment spec).** Owner can assign any driver/truck to any trip regardless of whether that resource is already on another active trip — no error, no confirmation prompt. `isResourceBusy` and the "driver/truck currently on an active trip" exception are gone from the backend entirely. Flutter Owner flow consolidated: **one Trip Form screen** (origin, destination, driver dropdown, truck dropdown) handles both create (`POST /trips`) and edit (`PATCH /trips/:id`, replaces the old `/trips/:id/assign` endpoint) — trips are fully editable after creation via the same form, reached via an Edit action on the trip's detail screen. The Owner's trip detail screen (tapping a trip card) shows driver/truck assignment, a read-only live expense view (reusing the same `ExpensesListView` the driver uses, edit/delete hidden), and a placeholder section for live location — actual tracking is deferred until Duty Status/Location steps (8-11) are built. Implemented 2026-08-09.
13. **Truck management, default truck, delivery date, and a standalone trips export were added ahead of the numbered Build Order** (all additive, no earlier override reversed). Owner-only **Trucks tab**: add/edit truck with `plate` (Truck Number), `brand`, optional `vin`. **Driver now has `defaultTruckId`**, set from the Add/Edit Driver form (new `PATCH /drivers/:id` endpoint — driver editing didn't exist before this); selecting a driver in the Trip Form pre-fills the Truck dropdown from that driver's default, still freely changeable. **Delivery date**: the `Trip.scheduledAt` column (present in schema since Trip Assignment was first built, never previously exposed) is now surfaced in the Trip Form as "Delivery Date" — Today/Tomorrow quick-picks plus a full calendar — and shown on both trip detail screens. **Actual delivery recording**: `Trip.startedAt`/`completedAt` (also long-present, previously never written) are now set automatically on the ASSIGNED→IN_TRANSIT and →DELIVERED/FAILED status transitions, and displayed as "Delivered/Failed on" on the trip detail screens. **Excel export**: `GET /trips/export.xlsx` (Owner-only, `exceljs`) — one worksheet per driver (origin, destination, truck, delivery date, status, started/completed timestamps), "Unassigned" sheet for trips with no driver. This is deliberately a separate, standalone exporter from the Financial Reporting workbook in Build Order step 17 — do not merge them; step 17's consolidated workbook is still a distinct, much larger piece of work (Sales/Expenses/Orders/Driver Expenses, gated on the Orders module and the revenue-tracking Open Decision). Implemented 2026-08-11.
14. **Owner Dashboard tab + bottom-tab shell added ahead of the numbered Build Order** (client request, additive). Owner navigation is now a two-tab bottom bar (Dashboard / Trips) with a centered **+** quick-actions FAB between them (Create Trip / Add Driver / Add Truck). Dashboard shows: fleet counts (tap-through to full lists), trip counts by status, Due Today/Due Tomorrow/Overdue lists (from `scheduledAt`), a weekly expense pulse (Fuel/Fine/Other breakdown), unclosed/failed trip counts, the Excel export button, and the Online Drivers list (Override 16). Trip cards on the Trips tab show each trip's expense total. **Owner can also act on a driver's behalf**: `ExpensesService.create/update/delete` now allow `OWNER` (attributed to the trip's assigned driver, not the Owner, so driver-expense reporting stays correct — `BadRequestException` if the trip has no driver yet), and the Owner trip detail screen has "Mark Delivered"/"Mark Failed" buttons (visible only while `IN_TRANSIT`, confirmation dialog first) for when a driver doesn't record it themselves. Implemented 2026-08-15.
15. **Driver self-assign trips (client request, reverses "Owner-only" assumption in the original Trip Assignment spec).** A Driver might be unavailable to receive an Owner-assigned trip, so Drivers can now create their own: `POST /trips` accepts `Role.DRIVER` in addition to `Role.OWNER`; when a Driver creates a trip, `TripsService.create` **forces `driverId` to the caller's own id** server-side regardless of what's in the request body (a driver can never assign a trip to someone else). The Trip Form hides the driver dropdown entirely in this mode (`TripFormScreen(selfAssignDriverId: ...)`) and pre-fills the truck from the driver's own `defaultTruckId` via a new self-service `GET /drivers/me` endpoint (also returns `isOnline`). `GET /trucks` (list + get-by-id) is now readable by `DRIVER` too (was Owner-only), since the self-assign form needs the truck dropdown. Trip editing (`PATCH /trips/:id`) stays Owner-only — this override is create-only. Implemented 2026-08-15.
16. **Duty Status + location tracking wired up (Build Order steps 8-11), foreground-only for now.** The `DriverShift` table and `go-online`/`go-offline` endpoints already existed from earlier scaffolding (unused until now) — the new work is `POST /drivers/me/location` (Driver-only ping, requires an active shift, attaches the driver's current `IN_TRANSIT` trip id if any) and `GET /drivers/online-locations` (Owner-only, latest ping per online driver). Flutter Driver home screen has an Online/Offline `Switch`; going online starts a `Timer.periodic` 60s ping loop using the `geolocator` package (works on both Chrome/web and Android — same code, no platform branching needed) and sends one ping immediately rather than waiting for the first tick. **This is foreground-only** — tracking stops if the app is closed or backgrounded, because there is no real background/foreground-service implementation yet (that needs `flutter_background_service`/`workmanager` + an Android foreground-service notification, a distinct follow-up step). Owner's "map" (step 11) is deliberately a lightweight text list on the Dashboard (name, green dot, "Xm ago"), not `flutter_map`/OpenStreetMap — kept intentionally minimal per client request; the real map is still future work. Implemented 2026-08-15.
17. **Android platform added.** The Flutter app was Chrome/web-only through Override 14; Android SDK (platform 36, build-tools 28.0.3/35.0.0, command-line tools only — no Android Studio IDE) was installed to `C:\Android\sdk` and the project scaffolded with `flutter create --platforms=android .`. `INTERNET`/`ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` permissions added to `AndroidManifest.xml`. Web remains the primary dev loop (faster iteration); Android is for real device/GPS testing, particularly of Override 16's location tracking. No emulator is set up (no AVD system images installed) — testing needs a physical device with USB debugging or an emulator set up separately. Implemented 2026-08-15.
18. **Trip deletion added (client request, additive).** `DELETE /trips/:id`: Owner can delete any trip in their company regardless of status; Driver can only delete their own trip while it's still `ASSIGNED` (`ForbiddenException`/`BadRequestException` otherwise). Deleting a trip cascades in a transaction — its `Expense` rows are deleted, while `FuelReceipt`/`Issue`/`LocationPing` rows are unlinked (`tripId` set null) rather than deleted, since those are historical records that can outlive the trip. Both trip detail screens (Owner and Driver) got a delete icon in the AppBar; confirming shows a warning dialog listing what's at stake — expense count/total if any are logged, and for Owner, a note if the trip is already past `ASSIGNED` (in transit/delivered/failed). Implemented 2026-08-15.
19. **Silent token refresh added (bug fix — users were seeing raw "Unauthorized" exceptions).** The 15-minute access token had no refresh flow wired up client-side even though `POST /auth/refresh` already existed backend-side, so every screen threw a bare 401 once the access token aged out. `ApiService` now stores the refresh token alongside the access token, and a central `_send()` wrapper transparently refreshes + retries once on any 401 from an authenticated call; concurrent 401s dedupe onto a single in-flight refresh. Only a genuinely invalid/expired refresh token now surfaces to the user, via `onSessionExpired` (wired in `main.dart` to a `navigatorKey.popUntil(isFirst)` back to `LoginScreen`) — no snackbar, matches the existing silent-logout pattern. Backend refresh tokens are rotated on every use (new 30-day expiry each time, was 7 — `JWT_REFRESH_EXPIRATION`), so the effective session is a rolling window: a user who opens the app at least once every 30 days is never logged out. Implemented 2026-08-15.
20. **Owner-triggered Driver password reset, and Add Owner (client request, additive — delete/deactivate for both explicitly deferred).** `PATCH /drivers/:id/reset-password` (Owner-only): generates a fresh random temp password (not phone-based, unlike creation), forces `mustChangePassword: true` again, and clears `currentHashedRefreshToken` so the driver's existing session dies within one access-token cycle. Wired into the Drivers list's per-row menu, reusing the same temp-password dialog pattern as Add Driver. Separately — **adding a second Owner to an existing company had zero support before this**: `POST /auth/register` always creates a brand-new company, there was no path to add a peer Owner to one that already exists. New `owners` module (`POST /owners`, `GET /owners`, both Owner-only) closes that gap, mirroring Drivers exactly: temp password (`initialPassword` or phone fallback), `mustChangePassword: true`, share dialog. Flutter: `Add Owner` quick action (mirrors `Add Driver`), and an `Owners` dashboard tile/list (read-only for now — no edit, deactivate, or delete yet, all owners are equal peers with no primary/secondary distinction). Deleting/deactivating Owners or Drivers, and the "last remaining Owner" guardrail that would gate it, are explicitly out of scope for this round. Implemented 2026-08-15.
21. **"Open in Google Maps" deep link added to the Online Drivers list (client request, additive — does not reopen the flutter_map/OSM decision in Override 9).** Each online driver with a location ping now has a map icon that opens `https://www.google.com/maps/search/?api=1&query=<lat>,<lng>` via the `url_launcher` package — Google's universal cross-platform link, not a Maps SDK/API call, so it stays genuinely free with no API key or GCP billing account. Works identically on web (opens in browser) and Android (opens the Maps app if installed, browser otherwise) — no platform branching. Android needs an `<queries>` entry for `android.intent.action.VIEW` + `https` scheme (added to `AndroidManifest.xml`) since package-visibility restrictions on Android 11+ would otherwise silently fail the launch. The actual in-app live map (Build Order step 11, `flutter_map`/OpenStreetMap) is still future work — this is a cheap complement, not a replacement. Implemented 2026-08-15.
22. **Operations Report added — combined Trips + Expenses reporting, Weekly/Monthly/Quarterly (client request, ahead of the full Build Order step 15/17 reports, additive).** Quarterly was previously deferred (Override 10) but the period resolver was deliberately built so it's a one-line addition — this is that addition, done in `period.util.ts`. Dashboard trip/expense figures were all-time or client-computed-over-everything before this, which doesn't scale as trip volume grows; the new `GET /reports/operations?period=&date=` aggregates server-side instead: **trips** = created-in-period total, completed-in-period (delivered/failed, by status transition date not creation date) with a completion rate and a per-driver breakdown; **expenses** = logged-in-period total, by category, by driver. `GET /reports/operations.xlsx` exports the same data as a 3-sheet workbook (Summary / Trips by Driver / Expenses by Driver) — a separate, smaller export from the still-not-built consolidated Financial workbook (step 17), same relationship the standalone trip export (Override 13) already has to it. Per-trip profitability / revenue reporting is explicitly out of scope here — still blocked on the `freightAmount` Open Decision. Flutter: new `OperationsReportScreen` (segmented period picker, Trips card, Expenses card, Export button), reached by tapping the Dashboard's existing "This Week's Expenses" card — deliberately **no new bottom-tab**, kept as a tap-through destination rather than growing the nav shell. Implemented 2026-08-15.
23. **Operations Report: period-instance navigation + full-detail export (client request, same day follow-up to Override 22, additive).** The screen could only ever show the *current* week/month/quarter — the backend's `date` anchor param already supported any period, it just wasn't exposed. Added a second dropdown (client-generated, no new endpoint) listing the last 26 weeks / 24 months / 12 quarters to jump directly to any of them — arrows were considered and rejected in favor of this since stepping back dozens of periods one at a time doesn't scale. Also added `GET /reports/operations-detail.xlsx?period=&date=` — a **different** export from the summary one: not aggregated KPIs but the underlying line items for the selected period (Trips sheet: origin/destination/driver/truck/status/dates; Expenses sheet: date/driver/trip/category/amount/reason/notes), one flat sheet each rather than split per-driver like the all-time trip export, since a single-period sheet doesn't have enough rows per driver to justify separate tabs. A "consolidated all-history" export (one row per period, every period the company's ever had) was discussed and deliberately not built — full detail for one chosen period covers the real need better; revisit later if still wanted. Implemented 2026-08-15.

## Tech Stack (All Free/Open-Source)

- **Mobile**: Flutter (web + Android, Override 17) + Riverpod + go_router + drift + flutter_secure_storage + `geolocator` (in use, foreground-only — Override 16) + workmanager/flutter_background_service (still pending, needed for true background tracking) + flutter_map (OpenStreetMap, still pending) + fl_chart + share_plus + firebase_messaging
- **Backend**: NestJS + TypeScript + Prisma + PostgreSQL + Redis/BullMQ + exceljs + Cloudinary/MinIO
- **Deployment**: Render/Railway (API), Neon/Supabase (DB), Upstash (Redis), Cloudinary (files)
- **Architecture**: Feature-based modules, Controller → Service → Repository → Prisma (backend); Clean Architecture data/domain/presentation per feature (Flutter). Multi-tenant via `company_id` on every table.

## Feature Specs (condensed reference)

### Auth
- Owner self-registers (name, company, email/phone, password).
- Owner creates Drivers via `POST /drivers` → temp password returned, `mustChangePassword: true` forced.
- `PATCH /drivers/:id/deactivate` / `/reactivate` — soft-delete only, never hard-delete (historical trips/expenses reference drivers).
- `PATCH /drivers/:id/reset-password` (Override 20) — Owner-only, fresh random temp password, forces `mustChangePassword: true`, kills the driver's current refresh token.
- Owner adds a peer Owner to their own company via `POST /owners` (Override 20) — same temp-password flow as Drivers; `GET /owners` lists them. No deactivate/delete yet.
- **Tokens** (Override 19): 15-minute access token, 30-day refresh token, rotated on every `POST /auth/refresh` call. Mobile `ApiService` refreshes and retries transparently on a 401; only a dead refresh token bounces the user to `LoginScreen`.

### Trucks (Owner)
- `Truck`: `id, companyId, plate (Truck Number), brand, vin?, createdAt`. Standard CRUD (`/trucks`), Owner-only.
- `User.defaultTruckId` (driver's default truck): set via Add/Edit Driver form, validated to belong to the same company. Pre-fills the Truck dropdown when that driver is picked in the Trip Form (Override 13); still changeable per-trip from the same dropdown.

### Trip Assignment (Owner + Driver self-assign)
- **One Trip Form screen** (Override 12) handles both create and edit: origin, destination, driver dropdown, truck dropdown, delivery date (Override 13). `customer name`/`notes` from the original spec are still not built (no fields/columns for them yet) — not yet requested.
- **Driver self-assign** (Override 15): a Driver can also create a trip, always assigned to themselves — `TripFormScreen(selfAssignDriverId: ...)` hides the driver dropdown, backend forces `driverId` to the caller regardless of request body. Editing (`PATCH`) is still Owner-only.
- **Delivery date** (Override 13): `scheduledAt`, set at assignment time via Today/Tomorrow chips or a calendar picker.
- **No double-booking guard** (Override 12) — a driver/truck already on another active trip can still be assigned; this was built then explicitly removed.
- Creating a trip → `status: ASSIGNED`. FCM push to driver not yet built.
- Owner's trip detail screen (tap a trip card): shows driver/truck assignment, delivery date, an Edit action (opens the same Trip Form pre-filled), a read-only expense view (Owner can also add/edit/delete on the driver's behalf — Override 14), "Mark Delivered"/"Mark Failed" overrides (Override 14), and a "live location — coming soon" placeholder.
- **Delete** (Override 18): `DELETE /trips/:id`, scoped by role — Owner can delete any trip in the company at any status; Driver can only delete their own trip while `ASSIGNED`. Confirmation dialog warns about logged expenses (deleted along with the trip) and, for Owner, about deleting a trip that's already past `ASSIGNED`.

### Driver Trip Lifecycle
- Slide-to-confirm control (not tap) for Start Trip / End Trip — `slide_to_act` or equivalent custom widget.
- Start → `status: IN_TRANSIT` (also stamps `Trip.startedAt`). End → `status: DELIVERED` or `FAILED` (also stamps `Trip.completedAt` — Override 13).
- Starting/ending a trip does not control location tracking anymore (see Duty Status) — trip slider only changes trip status.
- **Home screen ("My Trips") layout (Override 11)**: lists completed trips (`DELIVERED`/`FAILED`) plus the current assigned/in-progress trip as one card. The card is tap-to-open only — no slide control, no expense info shown inline on this list.
- **Trip Detail screen**: reached by tapping the active trip card. Contains, in one place: the slide-to-start/end control, this trip's expense list (reusing the existing expense list view), and an "Add Expense" button that opens the existing expense form. This replaces the current split where the slider lived on the home list and expenses were a separate "Log Expenses" entry point.

### Duty Status (Online/Offline)
- Driver-controlled toggle, independent of trip status — like a ride-hail "go online" switch. Built (Override 16).
- `DriverShift` table: `driver_id, company_id, started_at, ended_at (nullable), date`.
- `POST /drivers/me/go-online`, `POST /drivers/me/go-offline`.
- While Online: 60s location ping, regardless of active trip. While Offline: tracking stops entirely. **Currently foreground-only** (Override 16) — "while Online" means "while the app is open," not a true background/OS-level service yet.
- `location_pings`: `trip_id` nullable (ping can exist with no active trip), `driver_id` always present.
- `POST /drivers/me/location` — generalized ping endpoint (Driver-only, requires an active shift), backend attaches `trip_id` if one is active.
- Owner list (`GET /drivers/online-locations`) shows all Online drivers with latest ping — currently a plain text list (name, online dot, last-ping time), not a map, plus a per-driver "Open in Google Maps" link (Override 21, free universal URL, not the Maps SDK). `flutter_map`/OpenStreetMap markers are still future work.
- Starting a trip while Offline → prompt driver to go online, don't hard-block. Going offline mid-trip → confirm before stopping tracking. **Not yet built** — the toggle exists but doesn't yet cross-check against an active trip.

### Trip Expenses & Catch-Up
- Categories: Fuel (amount, receipt photo, odometer optional), Fines (amount, reason, photo optional), Other (amount, category/note).
- Editable any time until Owner sets `Trip.financiallyClosed = true`.
- Catch-Up screen: `GET /drivers/me/trips/pending-expenses?date=` — lists trips with `financiallyClosed = false` and expense counts; tapping opens the **same** expense form used for live/post-trip entry (no duplicate UI).

### Orders / "Park" Module (Owner)
- `Order`: `id, company_id, date, customer_name, item, cft, amount, payment_mode (CASH|UPI|BANK_TRANSFER|CREDIT), created_at, updated_at`.
- Standard CRUD, Owner-only, list view sortable/filterable by date, FAB to add.
- Credit tracking beyond a running total is deferred (see Open Decisions).
.....
### Financial Reporting (Consolidated Excel)
- Not the same thing as the standalone `GET /trips/export.xlsx` (Override 13, per-driver trip sheets) — that already exists and stays separate; this section is the future Sales/Expenses/Orders/Driver-Expenses workbook, still gated on step 17.
- Periods: **Daily, Monthly, Six-Month** (quarterly deferred). One aggregator, reused for `?forma..t=json` (in-app) and `?format=xlsx` (download).
- Single workbook per period, sheets: **Summary** (sales, expenses, net, credit outstanding), **Daily Sales** (from Orders), **Daily Expenses** (fuel/fines/maintenance/site/other), **Orders Detail**, **Driver Expenses** (grouped by driver).
- Dashboard: compact "This Month" snapshot card (Revenue/Expenses/Net, color-coded).
- Full screen: Daily/Monthly/Six-Month segmented toggle, category donut, six-month trend line, single "Export" action regardless of period selected.
- Nightly BullMQ job pre-generates prior day's report; cache in `Report` table (`company_id, type, date_range, driver_id nullable, file_url, generated_at`), regenerate only if underlying data changed since.

### Driver Efficiency Ranking
- Score 0–100 from: on-time delivery rate, trip completion rate, fuel cost/km (vs. fleet average), issue rate (inverted), doc/POD compliance.
- Weights configurable per company (settings table, not hardcoded).
- Minimum trip-count threshold before ranking eligibility.
- Leaderboard endpoint + Flutter screen (fl_chart bars per metric) + "Driver Rankings" sheet in the Excel workbook.

### Data-Entry Forms (Deferred)
- Customer amount, site expense, credit, and other business-specific forms are **not yet specced** — placeholders/routes only, no invented fields or validation. Wait for explicit field-level spec before building.

## Build Order (stop & wait after each step)

1. ✅ **Auth** — Owner-only register, `POST /drivers` temp password flow, deactivate/reactivate
2. **Flutter Owner** — Add Driver form + share dialog + deactivate/reactivate on list
3. **Flutter Driver** — Remove registration, add Set New Password screen
4. ✅ **Trucks CRUD** + **Trips** (reference pattern: Controller → Service → Repository)
5. ✅ Trip assignment form (double-booking guard built, then removed — Override 12)
6. ✅ Driver slide-to-start/end (trip status only)
7. ✅ Trip expense logging (fuel/fines/other), editable until `financiallyClosed`
8. ✅ Duty Status: `DriverShift` table + go-online/go-offline endpoints
9. ✅ Location ping: generalize endpoint, nullable `trip_id`, online-locations endpoint.
10. ✅ Flutter (Driver): Online/Offline toggle wired to 60s location service — **foreground-only**, not the background service originally specced (Override 16)
11. Flutter (Owner): Live Tracking map (online/idle markers) — currently a plain list, not a map (Override 16); real `flutter_map` still pending
12. Catch-Up expenses: pending-expenses endpoint + Flutter screen (reuses existing expense form)
13. Orders/"Park" module CRUD (backend + Flutter)
14. Fuel Receipts, site Expenses (placeholder), Maintenance, Documents, Issues, Notifications
15. Reports: Operational (driver activity, multi-sheet per driver)
16. Driver efficiency ranking (calculator + leaderboard)
17. Consolidated financial Excel (Summary/Daily Sales/Daily Expenses/Orders Detail/Driver Expenses sheets) — **confirm revenue/freight tracking decision first**
18. Financial Report Flutter screen (Daily/Monthly/Quartarly/Six-Month + dashboard snapshot card)
19. Report pre-generation + caching (nightly BullMQ)

## Open Decisions (resolve before the relevant step)

- **Revenue tracking**: does `Trip` get a `freightAmount` field for profit reporting, or does financial reporting stay cost/sales-only via Orders? Resolve before step 17.
- **Credit tracking depth**: is "Credit" payment mode just a report label, or does it need a linked receivables/payment-tracking table (who owes how much, when paid back)? Resolve before extending step 13/17.
- **"Park" naming**: confirmed as Orders/sales log unless corrected.
........
## Session Rules

- Small scoped steps, one module at a time.
- Don't re-read files this session unless forgotten.
- No full file dumps in chat....
- Stop & wait after each Build Order step.

---

*Saved: 2026-07-06, last updated 2026-08-15 (Override 22) — referenced on every module build
