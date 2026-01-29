#!/usr/bin/env python3
import argparse
import json
import os
import time
from decimal import Decimal
from urllib.parse import urlencode
from urllib.request import urlopen, Request

import boto3

TEXTSEARCH_URL = "https://maps.googleapis.com/maps/api/place/textsearch/json"
GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json"
DETAILS_URL = "https://maps.googleapis.com/maps/api/place/details/json"

STRONG_KEYWORDS = [
    "ethiopian", "eritrean", "habesha", "injera", "teff", "berbere",
    "amharic", "tigrinya", "tewahedo", "abyssinian", "addis", "asmara"
]

MEDIUM_KEYWORDS = [
    "east african", "horn of africa", "bunna", "coffee ceremony"
]


def _http_get(url, params):
    q = urlencode(params)
    req = Request(f"{url}?{q}", headers={"User-Agent": "habesha-ingest/1.0"})
    with urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def geocode_city(api_key, city, region, country):
    address = ", ".join([p for p in [city, region, country] if p])
    data = _http_get(GEOCODE_URL, {"address": address, "key": api_key})
    if data.get("status") == "OK" and data.get("results"):
        loc = data["results"][0]["geometry"]["location"]
        return float(loc["lat"]), float(loc["lng"])

    # Fallback: use Places Text Search (no location bias)
    data = _http_get(TEXTSEARCH_URL, {"query": address, "key": api_key})
    if data.get("status") == "OK" and data.get("results"):
        loc = data["results"][0]["geometry"]["location"]
        return float(loc["lat"]), float(loc["lng"])

    raise RuntimeError(f"Geocode failed for {address}: {data.get('status')}")


def textsearch(api_key, query, lat, lon, radius_m, pagetoken=None):
    params = {
        "query": query,
        "key": api_key,
        "location": f"{lat},{lon}",
        "radius": int(radius_m),
    }
    if pagetoken:
        params["pagetoken"] = pagetoken
    return _http_get(TEXTSEARCH_URL, params)


def place_details(api_key, place_id):
    params = {
        "place_id": place_id,
        "key": api_key,
        "fields": "formatted_phone_number,international_phone_number,website,opening_hours"
    }
    return _http_get(DETAILS_URL, params)


def score_place(name, address, types, matched_terms):
    text = " ".join([name or "", address or "", " ".join(types or [])]).lower()
    terms_text = " ".join(matched_terms or []).lower()

    score = 0
    reasons = []

    for kw in STRONG_KEYWORDS:
        if kw in text:
            score += 15
            reasons.append(f"kw:{kw}")
    for kw in STRONG_KEYWORDS:
        if kw in terms_text:
            score += 10
            reasons.append(f"q:{kw}")
    for kw in MEDIUM_KEYWORDS:
        if kw in text or kw in terms_text:
            score += 5
            reasons.append(f"kw:{kw}")

    if types:
        type_hits = {t for t in types if t in {"restaurant", "cafe", "church", "place_of_worship", "grocery_or_supermarket"}}
        if type_hits:
            score += 5
            reasons.append("type")

    score = min(100, score)
    needs_review = score < 60
    return score, needs_review, reasons[:10]


def to_decimal(v):
    return Decimal(str(v))


def build_item(place, city, category_id, matched_term, habesha_score, needs_review, reasons):
    loc = place.get("geometry", {}).get("location", {})
    lat = loc.get("lat")
    lng = loc.get("lng")

    item = {
        "PK": f"PLACE#{place.get('place_id')}",
        "SK": "META",
        "place_id": place.get("place_id"),
        "name": place.get("name"),
        "formatted_address": place.get("formatted_address"),
        "lat": to_decimal(lat) if lat is not None else None,
        "lng": to_decimal(lng) if lng is not None else None,
        "types": place.get("types", []),
        "rating": to_decimal(place.get("rating")) if place.get("rating") is not None else None,
        "user_ratings_total": to_decimal(place.get("user_ratings_total")) if place.get("user_ratings_total") is not None else None,
        "business_status": place.get("business_status"),
        "city_id": city["city_id"],
        "city_name": city["city"],
        "country": city["country"],
        "country_code": city["country_code"],
        "source": "google_places_textsearch",
        "matched_term": matched_term,
        "matched_terms": [matched_term],
        "category": category_id,
        "category_ids": [category_id],
        "habesha_score": to_decimal(habesha_score),
        "habesha_reasons": reasons,
        "needs_review": needs_review,
        "is_auto_ingested": True,
        "last_seen_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }

    # Remove None values
    return {k: v for k, v in item.items() if v is not None}


def merge_item(existing, new_item):
    if not existing:
        return new_item
    merged = existing

    # union lists
    merged_terms = set(merged.get("matched_terms", [])) | set(new_item.get("matched_terms", []))
    merged["matched_terms"] = sorted(merged_terms)

    merged_cats = set(merged.get("category_ids", [])) | set(new_item.get("category_ids", []))
    merged["category_ids"] = sorted(merged_cats)

    # keep highest score
    merged["habesha_score"] = max(merged.get("habesha_score", 0), new_item.get("habesha_score", 0))
    merged["needs_review"] = merged.get("habesha_score", 0) < 60

    # keep last_seen_at newest
    merged["last_seen_at"] = new_item.get("last_seen_at", merged.get("last_seen_at"))

    # if missing phone/website fields, keep newer
    for k in ["formatted_phone_number", "international_phone_number", "website", "opening_hours"]:
        if new_item.get(k) and not merged.get(k):
            merged[k] = new_item[k]

    return merged


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--api-key", default=os.getenv("GOOGLE_PLACES_API_KEY"))
    p.add_argument("--cities", default="scripts/cities_habesha_50.json")
    p.add_argument("--categories", default="scripts/categories_habesha.json")
    p.add_argument("--tables", action="append", default=None)
    p.add_argument("--radius-m", type=int, default=50000)
    p.add_argument("--max-pages", type=int, default=1)
    p.add_argument("--details", action="store_true")
    p.add_argument("--limit-cities", type=int, default=None)
    p.add_argument("--only-category", action="append", default=None)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    if not args.api_key:
        raise SystemExit("Missing API key. Set GOOGLE_PLACES_API_KEY or pass --api-key.")

    # Quick sanity check to fail fast if billing/API access is blocked
    probe = _http_get(TEXTSEARCH_URL, {"query": "ethiopian restaurant", "key": args.api_key})
    if probe.get("status") == "REQUEST_DENIED":
        raise SystemExit(f"Google Places API REQUEST_DENIED: {probe.get('error_message')}")

    with open(args.cities, "r", encoding="utf-8") as f:
        cities = json.load(f)
    with open(args.categories, "r", encoding="utf-8") as f:
        categories = json.load(f)

    if args.only_category:
        categories = [c for c in categories if c["id"] in set(args.only_category)]

    if args.limit_cities:
        cities = cities[: args.limit_cities]

    tables = args.tables or ["PlacesRaw", "allhabesha-v2-dev-PlacesRaw"]
    dynamodb = boto3.resource("dynamodb")
    table_objs = [dynamodb.Table(t) for t in tables]

    total = 0
    for city in cities:
        lat = city.get("lat")
        lon = city.get("lon")
        if lat is None or lon is None:
            lat, lon = geocode_city(args.api_key, city["city"], city.get("region"), city["country"])

        items_by_place_id = {}

        for cat in categories:
            for query in cat["queries"]:
                page = 0
                next_token = None
                while True:
                    if next_token:
                        time.sleep(2.0)
                    data = textsearch(args.api_key, query, lat, lon, args.radius_m, pagetoken=next_token)
                    status = data.get("status")
                    if status not in ("OK", "ZERO_RESULTS"):
                        print(f"WARN {city['city']} | {query} -> {status}")
                        break
                    results = data.get("results", [])
                    for place in results:
                        pid = place.get("place_id")
                        if not pid:
                            continue
                        matched_terms = [query]
                        score, needs_review, reasons = score_place(place.get("name"), place.get("formatted_address"), place.get("types", []), matched_terms)
                        item = build_item(place, city, cat["id"], query, score, needs_review, reasons)

                        if args.details:
                            d = place_details(args.api_key, pid)
                            if d.get("status") == "OK":
                                det = d.get("result", {})
                                for k in ["formatted_phone_number", "international_phone_number", "website", "opening_hours"]:
                                    if det.get(k):
                                        item[k] = det.get(k)

                        items_by_place_id[pid] = merge_item(items_by_place_id.get(pid), item)

                    next_token = data.get("next_page_token")
                    page += 1
                    if not next_token or page >= args.max_pages:
                        break

        if args.dry_run:
            print(f"{city['city']}: {len(items_by_place_id)} items (dry-run)")
            continue

        for table in table_objs:
            with table.batch_writer() as batch:
                for item in items_by_place_id.values():
                    batch.put_item(Item=item)
        total += len(items_by_place_id)
        print(f"{city['city']}: wrote {len(items_by_place_id)} items")

    print(f"Done. Total items processed: {total}")


if __name__ == "__main__":
    main()
