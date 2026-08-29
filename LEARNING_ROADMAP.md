# 15-Day Backend Learning Roadmap — Truck Management System

**Goal:** Actually understand and be able to rebuild the backend of this project from scratch. Frontend (Flutter) gets one dedicated day — enough to not be caught flat-footed, not full mastery.

**Method:** Don't just read this codebase — rebuild each day's piece yourself in a scratch project (or a `learning/` folder outside `apps/`), then compare against the real module. You learn by typing it, hitting the error, and fixing it — not by reading someone else's working code. Each day has: **Concepts → Read (real file) → Build (your own scratch version) → Checkpoint question**.

Suggested pace: ~2–3 hours/day. Adjust freely — this is a guide, not a contract.

---

## Day 1 — JS/TS + REST Fundamentals

**Concepts:** TypeScript types/interfaces, async/await, npm/package.json, what a REST API is (verbs, status codes, JSON bodies), client-server request/response cycle.

**Read:** `apps/api/src/main.ts`, `apps/api/package.json`

**Build:** A bare Node + TypeScript + Express (or plain `http`) server with one `GET /health` and one `POST /echo` route. No NestJS yet — feel the wiring you're about to have automated for you.

**Checkpoint:** Can you explain what a status code 201 vs 200 vs 400 vs 401 vs 403 each mean, and give one real example of each from this API?

---

## Day 2 — NestJS Core Concepts

**Concepts:** Modules, Controllers, Providers/Services, Dependency Injection, decorators (`@Module`, `@Controller`, `@Injectable`, `@Get`/`@Post`).

**Read:** `apps/api/src/modules/auth/` (whole folder — controller, service, module files)

**Build:** A scratch NestJS app (`nest new`) with a `CatsModule` — `CatsController` + `CatsService`, in-memory array storage, full CRUD. Focus on *why* the service is injected into the controller rather than instantiated with `new`.

**Checkpoint:** What breaks if you forget to add a provider to its module's `providers` array? Try it and read the actual error.

---

## Day 3 — PostgreSQL + Prisma Basics

**Concepts:** Relational tables, primary/foreign keys, one-to-many vs many-to-many, what an ORM does, Prisma schema syntax, `prisma migrate` vs `prisma db push`.

**Read:** `apps/api/prisma/schema.prisma` (all of it — don't skim)

**Build:** Add a `Cat` model to your scratch Prisma schema, run a migration, then rewrite Day 2's in-memory CRUD to hit real Postgres via `PrismaClient`.

**Checkpoint:** In this project's schema, why does almost every table have a `companyId`? What would break (or leak) if one table forgot it?

---

## Day 4 — Relations & Multi-Tenancy

**Concepts:** `@relation`, cascade vs `SetNull` vs `Restrict` on delete, filtering every query by tenant (`companyId`) so Company A never sees Company B's data.

**Read:** `apps/api/prisma/schema.prisma` (Trip's relations to Driver/Truck/Material/Supplier), any service's `findMany` calls (e.g. `trucks.service.ts`)

**Build:** Add `Owner` (company) → `Cat` relation to your scratch project. Add a second fake company and prove your `findMany` calls never cross tenants without you explicitly filtering — this is where real multi-tenant bugs live.

**Checkpoint:** Find one query anywhere in `apps/api/src/modules/` that filters by `companyId` and explain in your own words what would leak if that line were deleted.

---

## Day 5 — Auth Deep Dive

**Concepts:** Password hashing (bcrypt), JWT structure (header/payload/signature), access vs refresh tokens, Passport strategies, Guards, `@UseGuards`, role-based access control.

**Read:** `apps/api/src/modules/auth/` (strategy, service, guards in `common/guards`, `common/strategies`)

**Build:** Add login + JWT-protected routes to your scratch app: hash a password on signup, verify on login, issue a JWT, guard a route so it 401s without a valid token.

**Checkpoint:** Trace this project's refresh-token rotation end to end (Override 19 in CLAUDE.md) — why rotate the refresh token on every use instead of reusing one for 30 days straight?

---

## Day 6 — CRUD Reference Pattern (rebuild `trucks`)

**Concepts:** DTOs, `class-validator` decorators, Controller → Service → Prisma layering, why validation lives in DTOs not controllers.

**Read:** `apps/api/src/modules/trucks/` (entire module, it's this project's intentionally simplest CRUD reference)

**Build:** Without looking at the real file, rebuild the `trucks` module yourself from memory/understanding: `TrucksController`, `TrucksService`, `CreateTruckDto`, `UpdateTruckDto`, Owner-only guard. Then diff your version against the real one.

**Checkpoint:** What validation error do you get if you POST a truck with no `plate`? Where exactly does that get caught — controller, DTO, or Prisma?

---

## Day 7 — Guards, Roles, and Ownership Rules

**Concepts:** Custom guards, role decorators (`@Roles`), request-scoped `req.user`, enforcing "you can only touch your own company's data."

**Read:** `apps/api/src/common/guards/`, `apps/api/src/common/decorators/`

**Build:** Add a `@Roles('ADMIN')` guard to your scratch app that 403s non-admins. Then add an ownership check (a user can edit their own cat but not someone else's).

**Checkpoint:** In `trips`, why is `PATCH /trips/:id` Owner-only while `POST /trips` is allowed for both Owner and Driver? What server-side line enforces the driver-can't-assign-to-someone-else rule?

---

## Day 8 — State Machines (rebuild the `trips` lifecycle)

**Concepts:** Enum-based status fields, valid state transitions, side effects on transition (stamping timestamps), why this belongs in the service layer not the controller.

**Read:** `apps/api/src/modules/trips/` (full module — this is the most complex one in the app)

**Build:** In your scratch app, build an `Order` with states `PENDING → SHIPPED → DELIVERED`, each transition stamping a timestamp, each transition validated (can't go `PENDING → DELIVERED` directly).

**Checkpoint:** Read Override 18 in CLAUDE.md (trip deletion). Why does deleting a trip cascade-delete `Expense` rows but only null out `tripId` on `LocationPing`? What's the reasoning difference?

---

## Day 9 — Delegated Permissions (rebuild `expenses`)

**Concepts:** One role acting on behalf of another (Owner logging an expense attributed to a Driver), attribution vs actor, guarding against a role acting on behalf of themselves incorrectly.

**Read:** `apps/api/src/modules/expenses/`

**Build:** Extend your scratch `Order` app: let an `ADMIN` create an order "on behalf of" a `CUSTOMER`, but the order's `customerId` must always reflect the real customer, never the admin.

**Checkpoint:** In this codebase, what exception is thrown if an Owner tries to log an expense on a trip that has no driver assigned yet, and why does that check need to exist?

---

## Day 10 — Aggregation & Reporting

**Concepts:** `groupBy`, date-range filtering, period resolvers (week/month/quarter anchoring), building Excel files server-side (`exceljs`), streaming a file response.

**Read:** `apps/api/src/modules/reports/` (especially `period.util.ts`), any `export.xlsx` endpoint

**Build:** Write a `GET /orders/summary?period=weekly` in your scratch app that groups orders by day within the resolved week, then a `GET /orders/export.xlsx` that dumps them to a spreadsheet with `exceljs`.

**Checkpoint:** Why was the period resolver "deliberately structured so quarterly is a one-line addition later" (per CLAUDE.md)? Look at the actual function — what's the one line?

---

## Day 11 — File Uploads

**Concepts:** Multipart form data, cloud storage (Cloudinary/MinIO), storing a URL vs storing a blob in Postgres, signed URLs.

**Read:** `apps/api/src/modules/uploads/`

**Build:** Add an image upload endpoint to your scratch app (local disk is fine for practice) and store just the resulting path/URL in the DB.

**Checkpoint:** Why does this project store expense receipt photos as URLs in Postgres instead of as binary blobs in the database?

---

## Day 12 — Testing & Debugging Discipline

**Concepts:** Unit vs integration tests, mocking Prisma in NestJS tests, manual API testing (Postman/curl/Thunder Client), reading a NestJS stack trace, common error classes (`BadRequestException`, `ForbiddenException`, `NotFoundException`).

**Read:** Any `*.spec.ts` files in `apps/api/src/` if present; otherwise NestJS testing docs

**Build:** Write one unit test for your scratch `TrucksService`-equivalent (mock Prisma), and one e2e test hitting a real route with `supertest`.

**Checkpoint:** Deliberately break something (e.g. remove a `companyId` filter) and write a test that would have caught it.

---

## Day 13 — Config, Env, and Deployment

**Concepts:** `.env` files, secrets management, environment-specific config, running migrations against a hosted DB (Neon/Supabase), deploying a Node API (Render/Railway).

**Read:** `apps/api/app.env.example` (or equivalent), any `Dockerfile`/deployment config in the repo

**Build:** Deploy your scratch NestJS + Prisma app to Render (free tier) with a Neon Postgres DB. Run your first migration against a real hosted database, not localhost.

**Checkpoint:** What's the difference between `prisma migrate deploy` (production) and `prisma db push` (used a few times in this project's overrides)? Why is `db push --accept-data-loss` explicitly called out as risky in CLAUDE.md Overrides 26/27?

---

## Day 14 — Full-Stack Trace (your one Flutter day)

**Concepts:** Just enough Flutter/Riverpod/go_router to trace a request, not to write one from scratch: widget → API service call → HTTP request → NestJS controller → service → Prisma → Postgres → response → state update → UI rebuild.

**Read:** Pick one real feature (e.g. "Owner marks a trip Delivered") and read it in both directions: `apps/mobile/lib/screens/...` → `ApiService` call → `apps/api/src/modules/trips/trips.controller.ts` → `trips.service.ts` → Prisma → back up.

**Build:** Nothing new — instead, write yourself a one-page trace diagram/notes of that single request's full path, including exactly which file changes the DB row and which file updates the UI.

**Checkpoint:** If you had to explain "how does marking a trip Delivered work" in an interview, could you do it file-by-file without opening the code?

---

## Day 15 — Capstone (solo, no AI)

**Goal:** Prove it to yourself. Design and build one small new real module in your scratch app end-to-end, alone: schema change, migration, DTO, controller, service, guard, and a Postman test — no AI assistance, no copy-pasting from this repo.

Suggestion: a `Maintenance` module (truck maintenance records) — it's mentioned as unbuilt in CLAUDE.md's Build Order (step 14) and referenced in Override 30's `ON DELETE RESTRICT` note, so it's realistic scope and you can compare your design against the constraint that's already documented.

**Checkpoint:** Could you defend every line you wrote if someone asked "why did you do it this way" in a live review?

---

## Notes

- Skip a day's "Build" step if you're short on time, but never skip the "Checkpoint" — if you can't answer it, the day isn't done yet.
- Keep your scratch project completely separate from `apps/api` — you want to feel the friction of setting things up yourself, not edit the working app.
- Revisit CLAUDE.md's numbered Overrides as you go — most of them are real war stories (a bug found, a client reversal) that explain *why* the code looks the way it does, which is usually more instructive than the code itself.
