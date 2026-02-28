# moment (iOS)

`moment` is a native iOS voice note app built with SwiftUI and Core Data. It supports text notes, image notes, voice recording with live transcription, and a simple backend-powered sync + AI summarization flow.

## Features

- Notes list with search, tags, and list/grid layout toggle
- Text notes and image notes (multi-image support)
- Voice notes
  - Live transcription while recording (Apple Speech)
  - Saves audio file + transcript into Core Data
  - Optional backend AI summarization after recording stops
- Favorites
- Todos
  - Create todos inside note content using `○ ` (open) and `● ` (done)
  - Optional deadline suffix: `@YYYY-MM-DD`
  - Todo list view aggregates tasks across notes
  - Sync todos to Apple Reminders (EventKit) when permissions are granted
- Calendar
  - Shows upcoming events (next 7 days) when Calendar access is granted

## Tech Stack

- UI: SwiftUI
- Local storage: Core Data (`moment/moment.xcdatamodeld`)
- Audio recording/playback: AVFoundation
- Live transcription: Apple Speech (`Speech` framework)
- Offline transcription (file-based): WhisperKit (loads `openai/whisper-small-v3`)
- Calendar/Reminders integration: EventKit
- Backend (optional but recommended): JWT auth + `/sync` + media uploads + `/ai/summarize`

## Requirements

- Xcode (project: `moment.xcodeproj`)
- iOS deployment target: `18.6` (see `moment.xcodeproj/project.pbxproj`)
- Simulator destination used by CI/dev scripts: `platform=iOS Simulator,name=iPhone 16`

## Configuration

### 1) Backend URL

Update `moment/Secrets.swift`:

- `Secrets.backendURL` (default is `http://localhost:8000`)

The app uses this backend for:

- Auth: `/auth/register`, `/auth/login`, `/auth/me`
- Sync: `/sync`
- Media uploads: `/storage/presigned-url`
- AI summarization: `/ai/summarize`

API expectations are documented in `BACKEND_APIS.md`.

### 2) Gemini API Key (optional)

`moment/Secrets.swift` includes `Secrets.geminiAPIKey`. The current app flow uses the backend summarization endpoint by default; a direct Gemini transcription service exists behind `canImport(GoogleGenerativeAI)` but may require adding the package.

## Permissions

The project includes usage descriptions for:

- Microphone (voice recording)
- Speech Recognition (live transcription)
- Photos + Camera (image notes)
- Calendar + Reminders (events + reminder sync)

If live transcription appears to do nothing in the Simulator, test on a real device (Speech + audio routing can be unreliable in Simulator for some setups).

## Build & Test (CLI)

Build:

```bash
xcodebuild -project moment.xcodeproj -scheme moment -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Clean:

```bash
xcodebuild clean -project moment.xcodeproj -scheme moment
```

Run all tests:

```bash
xcodebuild test -project moment.xcodeproj -scheme moment -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'
```

Run a single test:

```bash
# Syntax: -only-testing:[TestTarget]/[TestClass]/[TestMethod]
xcodebuild test -project moment.xcodeproj -scheme moment -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:momentTests/NoteServiceTests/testCreateNote
```

## Project Layout

```
moment/
  Controllers/   ObservableObject view logic
  Extensions/    Swift extensions
  Models/        Core Data helpers + extensions
  Services/      Audio, auth/sync, transcription, AI
  Shared/        Design system + reusable components
  Views/         SwiftUI screens/components
```

## Notes

- Authentication tokens are stored in Keychain (see `APIService` in `moment/Services/AuthenticationService.swift`).
- Recording UX is driven by a global overlay (`moment/Views/AudioRecordingOverlay.swift`) powered by `moment/Services/GlobalAudioService.swift`.
