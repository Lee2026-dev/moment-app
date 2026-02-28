# AGENTS.md

Guidelines for agentic coding assistants working on the `moment` iOS SwiftUI application.

## Project Overview

`moment` is a native iOS offline-first voice note application built with SwiftUI, CoreData, AVFoundation, and a custom backend for sync. It supports recording, live and offline transcribing (Apple Speech & WhisperKit), and managing voice and text notes with a high-end "Pro-Max" design aesthetic.

## Build and Test Commands

Use `xcodebuild` for command-line operations on the main iOS app, and `swift` for the Shared package.
**SDK**: `iphonesimulator` | **Destination**: `platform=iOS Simulator,name=iPhone 16`

### iOS App Commands
- **Build Project**:
  ```bash
  xcodebuild -project moment.xcodeproj -scheme moment -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
  ```
- **Clean Build**:
  ```bash
  xcodebuild clean -project moment.xcodeproj -scheme moment
  ```
- **Run All Tests**:
  ```bash
  xcodebuild test -project moment.xcodeproj -scheme moment -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'
  ```
- **Run Single Test**:
  ```bash
  # Syntax: -only-testing:[TestTarget]/[TestClass]/[TestMethod]
  xcodebuild test -project moment.xcodeproj -scheme moment -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:momentTests/NoteServiceTests/testCreateNote
  ```

### Shared Package Tests (`MomentShared/`)
If working on decoupled logic inside `MomentShared`:
- **Run All SPM Tests**:
  ```bash
  cd MomentShared && swift test
  ```
- **Run Single SPM Test**:
  ```bash
  cd MomentShared && swift test --filter TodoSyncServiceTests.testDeleteTodo_RemovesLineFromNote
  ```

## Code Style Guidelines

### 1. Naming Conventions
- **Files**: `PascalCase` (e.g., `NoteListView.swift`, `AudioService.swift`).
- **Types**: `PascalCase` (e.g., `NoteService`, `struct NoteCard`).
- **Variables/Methods**: `camelCase` (e.g., `isRecording`, `fetchNotes()`).
- **Constants**: `PascalCase` for design tokens (e.g., `MomentDesign.Colors.primary`).
- **Private Properties**: Prefix with underscore `_` only when absolutely necessary (e.g., backing state).

### 2. Imports
Group imports alphabetically in this exact order:
1. Apple Frameworks (`SwiftUI`, `CoreData`, `AVFoundation`, `Combine`, `EventKit`)
2. Third-party (`FirebaseCore`, `WhisperKit`, `GoogleGenerativeAI`)
3. Internal Modules (e.g., `MomentShared`)

### 3. File Header & Documentation
- **Header**: Use standard Xcode header with creation date.
- **Public APIs**: Use triple-slash `///` with parameter/return descriptions.
- **Sections**: Use `// MARK: - [Section]` (e.g., `Properties`, `Lifecycle`, `Methods`, `Subviews`).
- **Complex Logic**: Add inline comments explaining "why", not "what".

### 4. SwiftUI View Structure
Maintain strict order of declarations:
1. `@Environment`, `@EnvironmentObject`
2. `@StateObject` (Controllers)
3. `@State`, `@Binding`, `@AppStorage`
4. Standard Properties (`let`, `var`)
5. `init`
6. `body`
7. Subviews (`// MARK: - Subviews`)
8. Methods (`// MARK: - Methods`)

### 5. Error Handling (Strict)
- Use `do-catch` for all failable operations. Do **not** use `try?` unless the failure is genuinely optional and ignorable.
- **CoreData**: Explicitly handle context save errors. Always use `context.rollback()` on failure to prevent corrupted state.
- **Logging**: Print errors with domain context: `print("Error [AudioService]: \(error.localizedDescription)")`.
- **Never** suppress type errors with `as any`, `@ts-ignore`, or force unwrap `!` unless guaranteed safe by bounds.

### 6. Access Control
- Default to `internal` for module-wide access.
- Use `private` for implementation details to reduce autocomplete clutter.
- Mark singletons strictly as `static let shared = Service()` with a `private init()`.

## Architecture (MVVM-C)

- **Views** (`moment/Views/`): Declarative UI. Use `MomentDesign` tokens. Absolutely no business logic or direct CoreData saves.
- **Controllers** (`moment/Controllers/`): `ObservableObject` classes managing view state. Mark with `@MainActor` to ensure UI updates on main thread.
- **Services** (`moment/Services/`): Singletons (`.shared`) for business logic (Audio, Auth, Data, Sync).
- **Models** (`moment/Models/`): CoreData classes + Swift extensions for computed properties and type-safety.
- **Extensions** (`moment/Extensions/`): Swift extensions (Date+, View+).
- **Shared** (`moment/Shared/`): Design System (`MomentDesign`), ThemeManager, and reusable components.

### Key Global Objects (in `momentApp.swift`)
- **ThemeManager**: Controls app-wide theming (`.environmentObject`).
- **GlobalAudioService**: Controls audio playback state globally (`.environmentObject`).
- **AuthenticationService**: Manages JWT user auth state and Keychain.
- **PersistenceController**: CoreData stack (`.environment(\.managedObjectContext)`).
- **AudioRecordingOverlay**: Resides in the root `ZStack` for global recording access.

## Data Persistence & Sync

- **CoreData**: Primary offline-first storage. Use `@FetchRequest` in Views, and `NSFetchedResultsController` in Controllers.
- **Concurrency**: Use `context.perform` or `context.performAndWait` for background CoreData operations.
- **Audio/Images**: Large media are stored locally in `Documents/Audio/` and synced via **Presigned URLs** (S3). Filenames use UUIDs.
- **Syncing**: Managed by `SyncEngine` (`/sync` endpoint). Uses a Delta Sync approach tracking `syncStatus` (0=Synced, 1=Pending, 2=Error) and `last_synced_timestamp`.
- **Todos**: Extracted from notes (`○ ` and `● `) and synced to Apple Reminders via EventKit.

## UI/UX & Design System

- **Colors**: Strictly use `MomentDesign.Colors` (e.g., `background`, `primaryText`). Avoid hardcoded colors.
- **Typography**: `MomentDesign.Typography` for standardized fonts.
- **Components**: Reuse `MomentComponents` where available.
- **Icons**: Use SF Symbols. No emojis unless requested.
- **Haptics**: Trigger feedback via `HapticHelper` (`.light()`, `.medium()`, `.success()`).

## Secrets & API
- Environment config lives in `moment/Secrets.swift`.
- Backend API default is `http://localhost:8000` for `/auth`, `/sync`, `/storage/presigned-url`, and `/ai/summarize`.
