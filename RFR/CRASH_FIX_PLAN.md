# Crash Troubleshooting Plan

## Identified Issues

### 1. **CRITICAL: ModelContext Not Available in fullScreenCover**
- **Problem**: `LiveWorkoutView` uses `@Environment(\.modelContext)` but fullScreenCover doesn't inherit environment from parent
- **Impact**: Crash when trying to save workout history
- **Fix**: Pass modelContext explicitly or use a different approach

### 2. **Timer Closure Variable Capture Issue**
- **Problem**: `elapsed` variable is captured in Timer closure but modified inside Task
- **Impact**: Race condition, incorrect timing
- **Fix**: Use instance variable or proper synchronization

### 3. **LocationService Background Updates**
- **Problem**: `allowsBackgroundLocationUpdates` set without checking capabilities
- **Impact**: Crash if Info.plist not configured correctly
- **Fix**: Add proper checks and error handling

### 4. **VoiceService Audio Session Setup**
- **Problem**: Audio session setup might fail silently
- **Impact**: No voice announcements, potential crash
- **Fix**: Better error handling

### 5. **WorkoutManager State Mutation Race Conditions**
- **Problem**: Session state mutated from multiple async contexts
- **Impact**: Data corruption, crashes
- **Fix**: Ensure all mutations happen on MainActor

### 6. **Singleton Initialization Order**
- **Problem**: Singletons accessed before initialization
- **Impact**: Crashes on app launch
- **Fix**: Lazy initialization or proper ordering

## Fix Priority

1. **HIGH**: ModelContext access in fullScreenCover
2. **HIGH**: Timer closure variable capture
3. **MEDIUM**: LocationService background updates
4. **MEDIUM**: State mutation race conditions
5. **LOW**: Audio session error handling



