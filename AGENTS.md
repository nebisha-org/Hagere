# AGENTS.md — Hagere / agerelige_flutter_client (V2)

Date: 2026-01-29
Owner: Nebyate Endalamaw
Repo: /Users/nebsha/FlutterProjects/AllHabesha/agerelige_flutter_client (branch: v2)

## ✅ Priority (must follow)
- Focus on **fast release**. Avoid extra commentary or scope beyond the current focus.

## 📁 AllHabesha repo map
- Frontend: /Users/nebsha/FlutterProjects/AllHabesha/agerelige_flutter_client
- Backend: /Users/nebsha/FlutterProjects/AllHabesha/agerelige-backend
- Backend v2: /Users/nebsha/FlutterProjects/AllHabesha/allhabesha-backend-v2

## ✅ Current state (what works now)
- Android emulator runs and shows list data.
- iOS simulator was fixed for navigation + location permissions flow.
- Real iPhone (00008130-001E350014BA001C) runs and **shows seeded Addis data** when location is set near Addis.
- API verified: `/entities` returns list with lat/lng filtering.

## ✅ QC mode + release (2026-02-10)
- QC mode enabled in release builds (no compile flag needed).
- 6‑second long‑press on the All Habesha title cycles: hidden → editing → stop edit → hidden.
- Stripe test/live strip only shows when QC is visible (or in non‑release).
- TestFlight build **1.0.1 (1766611766)** uploaded and App Store review submitted.

## 🔧 Key fixes already applied
- **Location hardcode removed** and proper permission flow restored.
- **Category tap** no longer blocked by location permission (non-blocking).
- Added **Enable Location** button on Places list screen + auto request on screen open.
- Added **lat/lng fallback** for `lng` fields in API.
- Fixed **Android MainActivity class name mismatch** in `AndroidManifest.xml`.
- Payments API now uses **baseUrl** correctly (fixes compile error).
- **Radius increased to 100 km** for list + providers.

## 📦 DynamoDB seed (Addis Ababa)
Added fake place to BOTH tables:
- `PlacesRaw`
- `allhabesha-v2-dev-PlacesRaw`

Seeded item:
- place_id: `FAKE_ADDIS_001`
- name: `Addis Habesha Cafe`
- address: `Bole Road, Addis Ababa, Ethiopia`
- lat/lon: `9.0054, 38.7636`
- source: `manual_seed`

Verified API response:
- `https://f76y479xbj.execute-api.us-east-2.amazonaws.com/entities?lat=9.0054&lon=38.7636&radiusKm=100&limit=50` returned 1 item.

## ✅ Files changed (major)
- `lib/state/providers.dart` (location flow, radius 100)
- `lib/state/location_name_provider.dart`
- `lib/api/entities_api.dart` (serverSideGeo optional, radius 100 default)
- `lib/utils/geo.dart` (lng fallback)
- `lib/screens/categories_screen.dart` (non-blocking navigation)
- `lib/screens/places_v2_list_screen.dart` (enable location button + auto request + radius 100)
- `lib/screens/entities_screen.dart` (lng fallback)
- `lib/services/payments_api.dart` (baseUrl fix)
- `lib/screens/add_listing_screen.dart` (accept id or SK)
- `android/app/src/main/AndroidManifest.xml` (MainActivity class fix)
- Various Android manifests/build files already modified in repo

## 🌍 Habesha ingestion system (NEW)
### New files
- `scripts/ingest_places.py` (Google Places → DynamoDB ingestion)
- `scripts/cities_habesha_50.json` (50-city global list)
- `scripts/categories_habesha.json` (Habesha-focused categories + search queries)

### What script does
- Pulls Google Places **Text Search** results by category + city.
- Auto-geocodes each city.
- Dedupe by `place_id`.
- Adds fields:
  - `habesha_score` (0–100)
  - `habesha_reasons`
  - `needs_review`
  - `category_ids`, `matched_terms`
- Writes to **both** tables: `PlacesRaw` + `allhabesha-v2-dev-PlacesRaw`

### IMPORTANT: Google Places API key issue
Key provided by user:
- `AIzaSyBnDEftuF13E6r1h3AnISk4xUhIqtXZxqg`

Error:
- `REQUEST_DENIED` → **Billing not enabled** on Google Cloud project.

Fix:
- Enable billing for that API key’s project.

Once billing is enabled, run:
```
source .venv/bin/activate
GOOGLE_PLACES_API_KEY="AIzaSyBnDEftuF13E6r1h3AnISk4xUhIqtXZxqg" python scripts/ingest_places.py --max-pages 1
```
Optional (adds phone/website; higher cost):
```
GOOGLE_PLACES_API_KEY="..." python scripts/ingest_places.py --max-pages 1 --details
```

## 🧪 Testing / run commands
- iOS simulator:
  `flutter run -d "iPhone 16e"`
- iOS device:
  `flutter run -d 00008130-001E350014BA001C`
- Android emulator:
  `flutter run -d emulator-5554`

## 📌 Next steps for tomorrow
1. **Enable Google Places billing** (required for ingestion).
2. Run `scripts/ingest_places.py` for the 50 cities.
3. Verify data in `PlacesRaw` and `allhabesha-v2-dev-PlacesRaw`.
4. Decide if Habesha score threshold should be adjusted (default: review if <60).
5. Clean up debug-only logs if needed before release.

## ⚠️ Notes / Risks
- If real device location is not near seeded data, list will show empty (expected). Seed data near user location to test.
- Location permissions on iOS must be enabled in Settings (if previously denied).
- Android device on Wi‑Fi not visible unless ADB pairing is done.

---

## Agent start point for tomorrow
Start with:
1) Enable billing for Google Places project (key above).
2) Run ingestion script with `--max-pages 1`.
3) Validate DynamoDB counts per city.
4) If needed, expand to `--max-pages 2`.
