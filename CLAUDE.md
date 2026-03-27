# Movie Watchlist API — Context for iOS Development

This file describes the local FastAPI server for the FeetForTarantino movie watchlist bot.
Use this as context when building the iOS app.

## Base URL

```
http://localhost:8000
```

Interactive docs (Swagger UI): **http://localhost:8000/docs**

Start the server:
```bash
cd ~/Workspace/personal/telegram/railway-deploy
source venv/bin/activate
uvicorn api:app --reload --port 8000
```

---

## Key Concept: chat_id

Every request is scoped to a Telegram `chat_id` (Int64).
This is the group chat ID from Telegram — it identifies which group's watchlist you're accessing.

---

## Models

### Movie

```swift
struct Movie: Codable, Identifiable {
    let id: Int
    let chatId: Int
    let title: String
    let status: String          // "to_watch" or "watched"
    let addedBy: String?
    let addedAt: String?        // ISO 8601 datetime
    let watchedBy: String?
    let watchedAt: String?      // ISO 8601 datetime, nullable
    let tmdbId: Int?
    let year: Int?
    let rating: Double?
    let posterPath: String?     // e.g. "/abc123.jpg"
    let genres: String?         // comma-separated genre IDs, e.g. "28,12,878"
}
```

Poster full URL: `https://image.tmdb.org/t/p/w500` + `posterPath`

### Stats

```swift
struct Stats: Codable {
    let toWatch: Int
    let watched: Int
}
```

### SearchResult

```swift
struct SearchResult: Codable {
    let tmdbId: Int
    let title: String
    let originalTitle: String?
    let year: String?
    let rating: Double?
    let overview: String
    let posterPath: String?
}
```

### Recommendation

```swift
struct Recommendation: Codable {
    let intent: String          // "similar", "mood", or "history"
    let sourceMovie: String?    // only for "similar" intent
    let suggestions: [Suggestion]
}

struct Suggestion: Codable {
    let title: String
    let year: String?
    let rating: Double?
    let overview: String?
    let posterPath: String?
    let tmdbId: Int?
    let reason: String          // explanation in Russian
}
```

---

## Endpoints

### GET /movies
Returns movies for a chat.

**Query params:**
- `chat_id: Int` — required
- `status: String?` — optional filter: `"to_watch"` or `"watched"`

**Examples:**
```
GET /movies?chat_id=-1001234567890                      → all movies
GET /movies?chat_id=-1001234567890&status=to_watch      → watchlist only
GET /movies?chat_id=-1001234567890&status=watched       → watched history
```

**Response:** `[Movie]`

---

### GET /movies/{id}
Returns a single movie.

**Query params:**
- `chat_id: Int` — required

**Example:**
```
GET /movies/42?chat_id=-1001234567890
```

**Response:** `Movie`
**Error:** `404` if not found

---

### POST /movies
Add a movie to the watchlist.

**Body (JSON):**
```json
{
  "chat_id": -1001234567890,
  "title": "Inception",
  "added_by": "iOS",
  "tmdb_id": 27205,
  "year": 2010,
  "rating": 8.4,
  "poster_path": "/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg",
  "genres": "28,12,878"
}
```

Only `chat_id` and `title` are required. Provide TMDB fields for richer data.

**Response:** `{"status": "added", "title": "Inception"}`
**Error:** `409` if movie already exists

---

### PATCH /movies/{id}/watched
Mark a movie as watched.

**Query params:**
- `chat_id: Int` — required

**Body (JSON):**
```json
{ "watched_by": "Daniiar" }
```

**Response:** `{"status": "watched", "title": "Inception"}`
**Error:** `400` if not found or already watched

---

### PATCH /movies/{id}/unwatch
Move a watched movie back to watchlist.

**Query params:**
- `chat_id: Int` — required

**Response:** `{"status": "to_watch", "title": "Inception"}`

---

### PATCH /movies/{id}/rename
Rename a movie.

**Query params:**
- `chat_id: Int` — required

**Body (JSON):**
```json
{ "new_title": "Inception (2010)" }
```

**Response:** `{"old_title": "Inception", "new_title": "Inception (2010)"}`

---

### DELETE /movies/{id}
Remove a movie.

**Query params:**
- `chat_id: Int` — required

**Example:**
```
DELETE /movies/42?chat_id=-1001234567890
```

**Response:** `{"status": "removed", "title": "Inception"}`
**Error:** `404` if not found

---

### GET /stats
Returns watchlist counts.

**Query params:**
- `chat_id: Int` — required

**Response:**
```json
{ "to_watch": 12, "watched": 34 }
```

---

### GET /search
Search for movies via TMDB.

**Query params:**
- `q: String` — movie title, optionally with year: `"Inception 2010"` or `"Начало (2010)"`
- `page: Int` — page number, 1–10 (default: 1)

**Example:**
```
GET /search?q=Inception
GET /search?q=Начало+2010
```

**Response:**
```json
{
  "results": [SearchResult],
  "total_pages": 5,
  "page": 1
}
```

Typical flow: search → user picks result → POST /movies with the tmdb_id and metadata.

---

### GET /recommendations
AI-powered movie recommendations via Groq (Llama 3.3 70B).

**Query params:**
- `chat_id: Int` — required (used for watch history context)
- `q: String` — optional query

**Intent auto-detection by query:**
- Empty `q` → `history` intent — recommendations based on group's watch history
- Movie title (e.g. `"like Inception"`, `"как Начало"`) → `similar` intent
- Mood/genre (e.g. `"мрачный триллер"`, `"something funny"`) → `mood` intent

**Example:**
```
GET /recommendations?chat_id=-1001234567890&q=
GET /recommendations?chat_id=-1001234567890&q=like+Inception
GET /recommendations?chat_id=-1001234567890&q=мрачный+триллер
```

**Response:** `Recommendation`

**Note:** Requires `GROQ_API_KEY` in server `.env`. Returns 3 suggestions enriched with TMDB data.

---

## Typical iOS Flows

### Display watchlist
```
GET /movies?chat_id=X&status=to_watch
→ show list with poster images
```

### Add movie with TMDB search
```
GET /search?q=user input
→ show search results
→ user selects one
POST /movies {chat_id, title, tmdb_id, year, rating, poster_path, genres}
```

### Mark as watched (swipe action)
```
PATCH /movies/{id}/watched?chat_id=X
{ "watched_by": "username" }
```

### Show AI recommendations
```
GET /recommendations?chat_id=X&q=
→ display 3 cards with reason in Russian
→ user taps "Add to watchlist" → POST /movies
```
