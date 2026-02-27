# JinoDiaryApp

A native macOS daily diary application built with SwiftUI. Single-window app with a calendar on the left and a rich text editor on the right, using golden ratio proportions for layout.

## Tech Stack

- **Language**: Swift (SwiftUI + AppKit via `NSViewRepresentable`)
- **Platform**: macOS 15.2+ (Sequoia). Has `#if os(macOS)` conditional compilation with minimal iOS fallback.
- **Database**: SQLite3 (raw C bindings, no ORM)
- **Dependencies**: None. Uses only Apple frameworks (SwiftUI, AppKit, Foundation, SQLite3).
- **Build**: Xcode 16.2+ (project version 3.0)
- **No tests, no CI/CD, no linting tools configured.**

## Project Structure

```
JinoDiaryApp/
├── CLAUDE.md                         # This file
├── README.md                         # Basic usage docs
├── .gitignore
├── .gitattributes
├── JinoDiaryApp.xcodeproj/           # Xcode project config
└── JinoDiaryApp/                     # All source code
    ├── JinoDiaryAppApp.swift         # @main entry point (18 lines)
    ├── ContentView.swift             # All UI + business logic (~1,745 lines)
    ├── SQLiteStorage.swift           # Database layer (~206 lines)
    ├── JinoDiaryApp.entitlements     # Empty entitlements
    ├── Assets.xcassets/              # App icons (16px-1024px) and accent color
    └── Preview Content/              # Xcode preview assets
```

The codebase is intentionally monolithic. Almost everything lives in `ContentView.swift`.

## Architecture

### Entry Point (`JinoDiaryAppApp.swift`)
- Single `WindowGroup` with `.windowStyle(.hiddenTitleBar)`
- Renders `ContentView()`

### UI & Business Logic (`ContentView.swift`)

**Top-level constructs (module scope):**
- `DateUtils` struct: Static date formatters (`yyyy-MM-dd`, `MMMM yyyy`, `EEEE, dd MMMM yyyy`, `dd MMMM yyyy`)
- `FormattingState` struct: Tracks `isBold`, `isItalic`, `isBulleted`
- Layout/color constants: `goldenRatio` (0.618), `appBackgroundColor`, `calendarBackgroundColor`, `todayButtonColor`, `activeFormattingButtonColor`, `inactiveFormattingButtonColor`

**ContentView (main view):**
- State: `@State attributedText`, `selectedDate`, `currentMonth`, `datesWithContent` (Set<String>), `pendingSave`
- `@StateObject textEditorController` (RichTextEditorController)
- Storage accessed via `SQLiteStorageService.shared` singleton through `DiaryStorage` protocol
- Layout: `GeometryReader` > `HStack` with left (calendar, 38.2%) and right (editor, 61.8%) columns
- Min window size: 1200x650

**Key components defined inside ContentView.swift:**
- `CalendarGrid` - Interactive month calendar with day selection, content indicators (bold blue for days with entries), today highlight, hover effects
- `MonthNavigationButton` - Chevron buttons for month navigation
- `TextFormattingButton` - Bold/italic/bullet toolbar buttons with active/inactive states
- `RichTextEditor` (macOS) - `NSViewRepresentable` wrapping `NSTextView` with `FormattingTextView` subclass and `RichTextEditorController`
- `RichTextEditor` (iOS fallback) - Minimal SwiftUI `TextEditor`
- `ListFormatting` - Bullet list management (uses `・` U+30FB as bullet character)
- `AcceptsFirstMouseWrapper` - macOS helper for accepting first mouse click in inactive window

**Save strategy:**
- Debounced auto-save: 0.8 second delay via `DispatchWorkItem` (`scheduleSave()`)
- Immediate save on date change, app deactivation, or app termination
- Backup triggered on app deactivation/termination (retains 3 latest)
- `datesWithContent` set updated on every text change

**Navigation functions:**
- `changeMonth(by:)` - Navigate months, selects first day of new month
- `changeMonthKeepingDay(by:)` - Navigate months, keeps same day number
- `changeDay(by:)` - Navigate days
- `goToToday()` - Jump to today
- `navigateToDayWithContent(direction:)` - Find next/previous day with content (searches up to 365 days)

### Data Layer (`SQLiteStorage.swift`)

**Protocol:** `DiaryStorage`
```swift
func loadEntry(for dateKey: String) -> Data?       // Returns RTF data
func saveEntry(_ data: Data?, for dateKey: String)  // nil deletes entry
func allDateKeys() -> Set<String>
func migrateFromUserDefaultsIfNeeded()
func performBackup(retaining latestCount: Int)
```

**Implementation:** `SQLiteStorageService` (singleton)
- DB path: `~/Library/Application Support/JinoDiary/diary.sqlite`
- Backup path: `~/Library/Application Support/JinoDiary/Backups/diary-yyyyMMdd-HHmmss.sqlite`
- Thread safety: Serial `DispatchQueue` (`com.jinodiary.storage`, QoS: `.userInitiated`)
- Schema: `entries` table with `date TEXT PRIMARY KEY`, `rtf_data BLOB`, `created_at REAL`, `updated_at REAL`
- Data format: RTF binary data (NSAttributedString serialized as RTF)
- Date key format: `yyyy-MM-dd`
- Migration: Supports legacy `UserDefaults` storage (both `[String: Data]` RTF and `[String: String]` plain text formats)

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+B` | Toggle bold |
| `Cmd+I` | Toggle italic |
| `Cmd+[` | Previous day |
| `Cmd+]` | Next day |
| `Cmd+Opt+[` | Previous day with content |
| `Cmd+Opt+]` | Next day with content |
| `Cmd+Shift+[` | Previous month |
| `Cmd+Shift+]` | Next month |
| `Cmd+T` | Go to today |

## Code Conventions

- **No external dependencies** - keep it that way. Use only Apple frameworks.
- **Monolithic file structure** - UI and business logic live in `ContentView.swift`. New features should be added there unless they clearly belong in a separate file (like a new storage backend).
- **SwiftUI-native state management** - `@State`, `@Binding`, `@StateObject`, `@Environment`. No third-party state management.
- **Module-level constants** for colors and layout values (not inside structs).
- **Protocol-based storage** - `DiaryStorage` protocol abstracts persistence. `SQLiteStorageService` is the concrete implementation accessed via `.shared` singleton.
- **Thread-safe database access** - All SQLite operations go through a serial dispatch queue.
- **RTF as data format** - Diary entries stored as RTF binary data, not plain text.
- **Date keys as strings** - `yyyy-MM-dd` format used as primary key for entries.
- **Golden ratio layout** - Left/right split uses `1 - 0.618` / `0.618` proportions.
- No tests exist. The app is built and tested manually via Xcode.
- **Do not run build or run commands.** The developer builds and runs the app themselves via Xcode. Never invoke `xcodebuild`, `swift build`, or similar commands.
