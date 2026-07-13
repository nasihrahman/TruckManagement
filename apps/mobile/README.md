# Truck Management Flutter UI

## Run locally

1. Install Flutter SDK.
2. From this folder, run:
   ```bash
   flutter pub get
   flutter run -d chrome
   ```
3. Make sure the NestJS API is running on `http://localhost:3000`.

## API base URL

The app reads `API_BASE_URL` from `.env`.

- For web: `http://localhost:3000/api/v1`
- For Android emulator: `http://10.0.2.2:3000/api/v1`
