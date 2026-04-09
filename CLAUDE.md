# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Approach
- Think before acting. Read existing files before writing code.
- Be concise in output but thorough in reasoning.
- Prefer editing over rewriting whole files.
- Do not re-read files you have already read unless the file may have changed.
- Test your code before declaring done.
- No sycophantic openers or closing fluff.
- Keep solutions simple and direct.
- User instructions always override this file.

## Core Principles

- Never use emojis.

## Commit Authorship

When committing code changes:
- Never add Claude as a commit author.
- Always commit as using the default git settings

## Build & Run

Build for simulator:
```
xcodebuild -project FeetForTarantino.xcodeproj -scheme FeetForTarantino -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Run tests:
```
xcodebuild -project FeetForTarantino.xcodeproj -scheme FeetForTarantino -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Run a single test class:
```
xcodebuild -project FeetForTarantino.xcodeproj -scheme FeetForTarantino -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:FeetForTarantinoTests/ClassName
```

The preferred workflow is through XcodeBuildMCP tools when available.

## Architecture

FeetForTarantino is a SwiftUI iOS app for shared movie watchlists tied to Telegram groups. There is no local database - all state comes from a REST API.

### Global State (injected via `.environment()` in `FeetForTarantinoApp`)

- `ChatStore` - manages saved chats (persisted to UserDefaults) and the active user identity per chat. Source of truth for which chat/user is selected.
- `PresenceManager` - sends heartbeats and polls online user IDs every 30 seconds.
- `WebSocketManager` - maintains a WebSocket connection and increments event counters (`movieEventCount`, `basketEventCount`) when the server pushes changes. ViewModels observe these counters to trigger refreshes.

### Directory Structure

```
FeetForTarantino/
  App/                   - Entry point (FeetForTarantinoApp, ContentView)
  Core/
    Models/              - Codable data models (Movie, BasketEntry, TelegramUser, etc.)
    Services/            - ChatStore, MovieService, PresenceManager, WebSocketManager
  Features/
    Watchlist/           - WatchlistView + WatchlistViewModel
    Search/              - SearchView + SearchViewModel
    Recommendations/     - RecommendationsView + RecommendationsViewModel
    MovieNight/          - MovieNightView + MovieNightViewModel + SpinWheelView
    Settings/            - SettingsView (no ViewModel)
  Shared/                - ShimmerCard (loading skeleton)
```

### Patterns

- All ViewModels use `@Observable` (not `ObservableObject`). Views own their ViewModels with `@State`.
- `MovieService` is a plain struct instantiated fresh inside each ViewModel - it is not shared or injected.
- ViewModels read from `@Environment` to get `chatStore`, then call `MovieService` methods directly.
- Deep link entry: `https://danchopon.github.io/feetfortarantino/chat?id=&name=` handled in `ChatStore.handle(_:)`.

### Backend URLs

- DEBUG: `http://localhost:8000` / `ws://localhost:8000/ws/{chatId}`
- RELEASE: `https://feetfortarantino.onrender.com` / `wss://feetfortarantino.onrender.com/ws/{chatId}`

The scheme is switched via `#if DEBUG` inside `MovieService.makeURL` and `MovieService.webSocketURL`.
