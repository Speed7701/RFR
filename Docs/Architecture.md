# RFR Swift Architecture & Implementation Plan

## 1. Product Overview
RFR Swift is a SwiftUI-based iOS training app that guides runners through configurable run/walk interval workouts. The experience spans workout authoring, music playback control, real-time run telemetry, proactive voice prompts, and post-run summaries. Durability, battery awareness, and seamless audio behavior are first-order concerns.

## 2. Guiding Principles
- **Glanceable UI:** Large typography, high contrast palettes, minimal cognitive load while running.
- **Predictable audio behavior:** Voice guidance must gracefully duck external audio without abrupt stops.
- **Resilient tracking:** Location, motion, and timers continue when backgrounded or when the device is locked.
- **Composable architecture:** Use MVVM with dependency injection and service protocols to maintain testability.
- **Data ownership:** Persist workouts, preferences, and history locally with Core Data (or SwiftData) and optionally sync to HealthKit.
- **Privacy-first:** Request permissions contextually and degrade features gracefully if access is denied.

## 3. High-Level Architecture

```
App Entry (RFRApp)
 └── DependencyContainer / AppEnvironment
     ├── PersistenceController (Core Data)
     ├── WorkoutTemplateStore
     ├── WorkoutHistoryStore
     ├── WorkoutEngine
     │    ├── IntervalScheduler
     │    ├── WorkoutTimer
     │    ├── LocationService
     │    ├── MotionService (CMPedometer, CMAltimeter optional)
     │    ├── PaceCalculator
     │    ├── AudioSessionManager
     │    └── VoiceGuidanceService
     ├── MusicCoordinator
     │    ├── AppleMusicService
     │    └── SpotifyService
     ├── NotificationScheduler
     ├── SettingsManager
     └── HealthKitManager (optional)
```

### 3.1 Module Breakdown
- **Foundation Layer:** Models, DTOs, persistence stores, shared utilities (time formatting, units).
- **Services Layer:** Concrete implementations for location, motion, audio, music, notifications, HealthKit. Each exposes protocol-driven interfaces for mocking.
- **Domain Layer:** `WorkoutEngine` orchestrates interval progression, telemetry updates, and voice cues. Manages state machine and interacts with services.
- **Presentation Layer:** SwiftUI views and view models for workout creation, library, active workout screen, and summaries.

## 4. Data Model

### Core Entities
- `WorkoutTemplate`  
  Fields: `id`, `name`, `createdAt`, `warmUpDuration`, `runDuration`, `walkDuration`, `intervalCount`, `coolDownDuration`, `notes`, `musicPreference`, `voicePreference`.

- `WorkoutInterval` (child of template)  
  Fields: `id`, `sequence`, `type (warmUp|run|walk|coolDown)`, `duration`, `targetPace` (future use).

- `WorkoutSession`  
  Fields: `id`, `templateId`, `startedAt`, `endedAt`, `distance`, `avgPace`, `totalTime`, `notes`, `exportedToHealthKit`.

- `IntervalEvent`  
  Fields: `id`, `sessionId`, `intervalType`, `startTime`, `endTime`, `distance`, `avgPace`.

> Persist workouts with Core Data/SwiftData. Provide migration path to SwiftData when iOS 17+ only.

### Settings & Preferences
Store in `UserDefaults` using `SettingsManager` for unit preference, default music source, voice prompt toggles, haptics toggle, and HealthKit sync flag.

## 5. Services

| Service | Responsibilities | Key APIs |
|---------|-----------------|----------|
| `LocationService` | High-accuracy location tracking, background updates, filtering via `horizontalAccuracy`, distance calculations | `CoreLocation` |
| `MotionService` | Step count cadence, fallback distance, optional | `CoreMotion` |
| `WorkoutTimer` | Interval timing, countdown scheduling, tolerates background pauses via `DispatchSourceTimer` + `BGTask` | `Foundation`, `BackgroundTasks` |
| `IntervalScheduler` | Turns templates into ordered phase list; tracks remaining intervals and emits transitions | Custom |
| `PaceCalculator` | Rolling average pace smoothing (e.g., exponential moving average) | Custom |
| `VoiceGuidanceService` | AVSpeechSynthesizer prompts, handles countdown cues, queue management | `AVFoundation` |
| `AudioSessionManager` | Configures `AVAudioSession` category `.playback` with `.duckOthers`, handles interruptions | `AVFoundation` |
| `MusicCoordinator` | Abstract façade for Apple Music & Spotify; handles auth, playback, metadata | `MusicKit`, `SpotifyiOS` |
| `NotificationScheduler` | Local notifications for background interval transitions | `UserNotifications` |
| `HealthKitManager` | Optional workout write/read | `HealthKit` |

All services conform to protocols exposed to view models and the workout engine to ensure testability.

## 6. Domain Logic: Workout Engine
- Accepts `WorkoutTemplate` and constructs ordered `WorkoutPhase` array: Warm-up → (Run/Walk)* → Cool-down.
- Manages state machine (`idle`, `preparing`, `countdown`, `active`, `paused`, `completed`, `aborted`).
- Emits published state to SwiftUI via `WorkoutSessionViewModel`.
- Coordinates timers, voice cues, notifications, and audio ducking.
- Records per-interval telemetry, updates Core Data periodically, and provides final summary.

## 7. Presentation Layer

### Key Screens
1. **Landing/Home** – quick start last workout, view history, configure settings.
2. **Workout Builder** – form-style inputs with validation, preview timeline, ability to duplicate templates.
3. **Workout Library** – list of saved templates, supports sorting and search.
4. **Workout Detail** – template summary, start button, default music pickers.
5. **Music Picker** – choose Apple Music playlist/album or connect Spotify.
6. **Active Workout** – large timer, current interval card, pace & distance metrics, circular progress indicator, playback controls, voice toggle, pause/resume, skip interval.
7. **Post-Workout Summary** – stats, per-interval breakdown, share button, option to save to HealthKit.
8. **Settings** – permissions status, units, voice options, background mode explanations.

### Design Considerations
- Use `NavigationStack` for hierarchical flows.
- Support `DynamicType` and high-contrast Color Scheme.
- Provide accessibility labels for voiceover (e.g., "Run interval in progress").
- Use `Gauge`, `ProgressView`, or custom `Canvas` for progress visualizations.

## 8. Audio & Voice Guidance
- Configure `AVAudioSession` with `.playback`, `defaultToSpeaker`, `mode: .spokenAudio`, `categoryOptions: [.mixWithOthers, .duckOthers]`.
- Voice prompts pipeline:
  1. `WorkoutEngine` posts upcoming event (e.g., 10-second transition).
  2. `VoiceGuidanceService` enqueues `AVSpeechUtterance`.
  3. `AudioSessionManager` triggers ducking when speech starts, restores on finish via delegate callbacks.
- Provide user settings to toggle countdown voice, interval stats, and warm-up/cool-down prompts.

## 9. Music Integration
- **Apple Music:** Use `MusicAuthorization` for access, `MusicCatalogSearchRequest`, `ApplicationMusicPlayer`. Persist selected playlists via `MusicItemID`. Handle subscription status gracefully.
- **Spotify:** Integrate `SpotifyiOS` SDK with client credentials + redirect URI. Manage token refresh and playback control via Spotify app remote.
- Unified playback controls presented in UI with capability detection (if user not authorized, show prompt).
- Ducking handled centrally via `AudioSessionManager`.

## 10. Background & Notifications
- Enable background modes: Audio, Location updates.
- Request `always` location authorization with user education screen.
- Use `startUpdatingLocation` + `allowsBackgroundLocationUpdates`.
- Schedule local notifications for interval transitions when app backgrounded.
- Use `BGAppRefreshTask` to handle long-running workouts if suspended.

## 11. Persistence & Offline
- Core Data stack with CloudKit disabled initially (future extension).
- Use background context for telemetry writes.
- Expose `WorkoutHistoryStore` for fetching aggregated stats (distance per week, fastest pace).
- Handle migration for schema changes via lightweight migrations.

## 12. HealthKit (Optional)
- Request `HKWorkoutType(.running)` write permission.
- On workout completion, export `HKWorkout` with segments representing intervals.
- Respect user choice to opt-in only once.

## 13. Security & Privacy
- Store Spotify tokens in Keychain.
- Provide privacy policy link in settings.
- Allow data deletion (clear history).
- Use approximate location toggle if user declines precise location (iOS 14+).

## 14. Implementation Roadmap
1. **Foundation Setup**
   - Define models, protocols, and dependency container.
   - Implement Core Data schema + PersistenceController.
2. **Workout Authoring**
   - Build workout builder view & view model.
   - Persist templates; create list/detail screens.
3. **Telemetry Services**
   - Implement `LocationService`, `WorkoutTimer`, `IntervalScheduler`.
   - Create `WorkoutEngine` and unit tests for state machine.
4. **Active Workout UI**
   - Compose `ActiveWorkoutView` consuming engine state.
   - Add pause/resume/skip controls.
5. **Voice Guidance**
   - Implement `VoiceGuidanceService`, audio ducking, user settings.
6. **Music Integration**
   - Add Apple Music first, feature-flag Spotify until authentication flow complete.
7. **Background Handling & Notifications**
   - Request permissions flow, background location, notifications.
8. **Workout Summary & History**
   - Persist sessions, display summaries, integrate sharing.
9. **HealthKit Export (Optional)**
   - Sync workouts, handle permission edge cases.
10. **Polish & QA**
   - Accessibility tuning, performance profiling, battery tests, offline edge cases.

## 15. Testing Strategy
- Unit tests for `WorkoutEngine`, `PaceCalculator`, persistence layer.
- Snapshot/UI tests for key SwiftUI views (use `ViewInspector` where helpful).
- Integration tests for location + timers using dependency injection and fakes.
- Manual field tests for GPS accuracy, audio ducking, and music playback.

## 16. Open Questions & Risks
- Spotify SDK requires developer account setup and tester whitelisting—confirm timeline.
- Decide between Core Data vs. SwiftData depending on iOS minimum version support.
- Evaluate HealthKit scope early to avoid late permission surprises.
- Investigate watchOS companion feasibility and sequencing.
- Battery impact from continuous GPS + speech + audio playback; consider user messaging.

---
This document guides the initial implementation phases. Update iteratively as architecture decisions evolve or scope changes.


