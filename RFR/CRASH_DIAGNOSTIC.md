# Crash Diagnostic & Fix Plan

## Current Issue
App crashes when selecting "Start Workout" - LiveWorkoutView fails to appear

## Potential Crash Causes Identified

### 1. **CRITICAL: Syntax Error in LiveWorkoutView**
- **Location**: Lines 33-50
- **Issue**: Double nested `if` statements with incorrect structure
- **Fix**: Simplified to single `if let` statement

### 2. **ModelContext Access**
- **Issue**: fullScreenCover may not inherit modelContext
- **Status**: Fixed - Removed explicit passing, relies on app-level container

### 3. **Service Initialization**
- **Issue**: Singletons accessed before initialization
- **Status**: Using @ObservedObject should handle this

### 4. **Timer Variable Capture**
- **Issue**: Race conditions in timer closure
- **Status**: Fixed - Using instance variable `elapsedTime`

### 5. **Location Service**
- **Issue**: Background location updates without proper setup
- **Status**: Added safety checks

## Fixes Applied

1. ✅ Fixed double `if` statement syntax error
2. ✅ Added NavigationStack wrapper
3. ✅ Added loading state for when session is nil
4. ✅ Added workout validation before starting
5. ✅ Improved error handling throughout
6. ✅ Fixed timer variable capture issue

## Next Steps for Debugging

1. **Enable Exception Breakpoints**:
   - In Xcode: Debug → Breakpoints → Create Exception Breakpoint
   - This will stop at the exact crash point

2. **Check Console Logs**:
   - Look for specific error messages
   - Check for "Fatal error" or "Thread" messages

3. **Test Incrementally**:
   - Comment out `.task` block temporarily
   - See if view appears without starting workout
   - If yes, issue is in workout start logic
   - If no, issue is in view rendering

4. **Verify Info.plist**:
   - Ensure all required keys are present
   - Background modes configured

## Most Likely Remaining Issue

The crash is likely happening because:
1. The view tries to access `workoutManager.session` before it's created
2. Or there's an issue with the NavigationStack structure

The fixes applied should resolve these issues. If crash persists, check Xcode console for specific error.



