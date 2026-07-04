# Truck Management Monorepo

Monorepo scaffold for Truck Management System.

Quick start (local dev):

1. Start dev services:

```bash
docker-compose up -d
```

2. Install dependencies and bootstrap the monorepo:

```bash
npm install
npm run bootstrap
```

3. API workspace:

```bash
cd apps/api
npm install
npx prisma generate
```
