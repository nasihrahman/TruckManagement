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

## Tech Stack (All Free/Open-Source)

- **Mobile**: Flutter + Riverpod + go_router + drift + flutter_secure_storage + geolocator + workmanager (or flutter_background_service for foreground location) + flutter_map (OpenStreetMap) + fl_chart + share_plus + firebase_messaging
- **Backend**: NestJS + TypeScript + Prisma + PostgreSQL + Redis/BullMQ + exceljs + Cloudinary/MinIO
- **Deployment**: Render/Railway (API), Neon/Supabase (DB), Upstash (Redis), Cloudinary (files)
- **Architecture**: Feature-based modules, Controller → Service → Repository → Prisma (backend); Clean Architecture data/domain/presentation per feature (Flutter). Multi-tenant via `company_id` on every table.

## Feature Specs (condensed reference)

### Auth
- Owner self-registers (name, company, email/phone, password).
- Owner creates Drivers via `POST /drivers` → temp password returned, `mustChangePassword: true` forced.
- `PATCH /drivers/:id/deactivate` / `/reactivate` — soft-delete only, never hard-delete (historical trips/expenses reference drivers).

### Trip Assignment (Owner)
- Form: driver (dropdown, excludes drivers on an active trip), truck (dropdown, excludes trucks on an active trip), origin, destination, scheduled start, customer name, notes.
- Service-layer guard against double-booking driver or truck on overlapping active trips.
- Creating a trip → `status: ASSIGNED` + FCM push to driver.

### Driver Trip Lifecycle
- Slide-to-confirm control (not tap) for Start Trip / End Trip — `slide_to_act` or equivalent custom widget.
- Start → `status: IN_TRANSIT`. End → `status: DELIVERED` or `FAILED`.
- Starting/ending a trip does not control location tracking anymore (see Duty Status) — trip slider only changes trip status.

### Duty Status (Online/Offline)
- Driver-controlled toggle, independent of trip status — like a ride-hail "go online" switch.
- `DriverShift` table: `driver_id, company_id, started_at, ended_at (nullable), date`.
- `POST /drivers/me/go-online`, `POST /drivers/me/go-offline`.
- While Online: 60s location ping via foreground service, regardless of active trip. While Offline: tracking stops entirely.
- `location_pings`: `trip_id` nullable (ping can exist with no active trip), `driver_id` always present.
- `POST /drivers/me/location` — generalized ping endpoint, backend attaches `trip_id` if one is active.
- Owner map (`GET /drivers/online-locations`) shows all Online drivers — distinct marker style for "on a trip" vs "idle."
- Starting a trip while Offline → prompt driver to go online, don't hard-block. Going offline mid-trip → confirm before stopping tracking./s

### Trip Expenses & Catch-Up
- Categories: Fuel (amount, receipt photo, odometer optional), Fines (amount, reason, photo optional), Other (amount, category/note).
- Editable any time until Owner sets `Trip.financiallyClosed = true`.
- Catch-Up screen: `GET /drivers/me/trips/pending-expenses?date=` — lists trips with `financiallyClosed = false` and expense counts; tapping opens the **same** expense form used for live/post-trip entry (no duplicate UI).

### Orders / "Park" Module (Owner)
- `Order`: `id, company_id, date, customer_name, item, cft, amount, payment_mode (CASH|UPI|BANK_TRANSFER|CREDIT), created_at, updated_at`.
- Standard CRUD, Owner-only, list view sortable/filterable by date, FAB to add.
- Credit tracking beyond a running total is deferred (see Open Decisions).

### Financial Reporting (Consolidated Excel)
- Periods: **Daily, Monthly, Six-Month** (quarterly deferred). One aggregator, reused for `?format=json` (in-app) and `?format=xlsx` (download).
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
4. **Trucks CRUD** + **Trips** (reference pattern: Controller → Service → Repository)
5. Trip assignment form + double-booking guard
6. Driver slide-to-start/end (trip status only)
7. Trip expense logging (fuel/fines/other), editable until `financiallyClosed`
8. Duty Status: `DriverShift` table + go-online/go-offline endpoints
9. Location ping: generalize endpoint, nullable `trip_id`, online-locations endpoint
10. Flutter (Driver): Online/Offline toggle wired to 60s background location service
11. Flutter (Owner): Live Tracking. map (online/idle markers)
12. Catch-Up expenses: pending-expenses endpoint + Flutter screen (reuses existing expense form)
13. Orders/"Park" module CRUD (backend + Flutter)
14. Fuel Receipts, site Expenses (placeholder), Maintenance, Documents, Issues, Notifications
15. Reports: Operational (driver activity, multi-sheet per driver)
16. Driver efficiency ranking (calculator + leaderboard)
17. Consolidated financial Excel (Summary/Daily Sales/Daily Expenses/Orders Detail/Driver Expenses sheets) — **confirm revenue/freight tracking decision first**
18. Financial Report Flutter screen (Daily/Monthly/Six-Month + dashboard snapshot card)
19. Report pre-generation + caching (nightly BullMQ)

## Open Decisions (resolve before the relevant step)

- **Revenue tracking**: does `Trip` get a `freightAmount` field for profit reporting, or does financial reporting stay cost/sales-only via Orders? Resolve before step 17.
- **Credit tracking depth**: is "Credit" payment mode just a report label, or does it need a linked receivables/payment-tracking table (who owes how much, when paid back)? Resolve before extending step 13/17.
- **"Park" naming**: confirmed as Orders/sales log unless corrected.

## Session Rules

- Small scoped steps, one module at a time.
- Don't re-read files this session unless forgotten.
- No full file dumps in chat.
- One clarifying question max per turn.
- Stop & wait after each Build Order step.

---

*Saved: 2026-07-06 — referenced on every module build
