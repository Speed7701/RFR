//
//  WorkoutManager.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import Foundation
import Combine

@MainActor
class WorkoutManager: ObservableObject {
    static let shared = WorkoutManager()
    
    @Published var session: WorkoutSession?
    @Published var isActive: Bool = false
    @Published var isPaused: Bool = false
    @Published var completedWorkout: WorkoutHistory?
    @Published var preWarmupCountdown: Int? = nil // nil = no countdown, 0-10 = countdown value
    
    private let locationService = LocationService.shared
    private let voiceService = VoiceService.shared
    private let musicService = MusicService.shared
    
    private var timer: Timer?
    private var countdownTimer: Timer?
    private var intervalStartDistance: Double = 0
    private var elapsedTime: TimeInterval = 0 // Instance variable to avoid capture issues
    private var countdownTriggered = false // Track if countdown has been triggered for current interval
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        locationService.$totalDistance
            .sink { [weak self] distance in
                guard let self = self, let session = self.session else { return }
                let updated = session
                updated.state.totalDistance = distance
                updated.state.intervalDistance = distance - self.intervalStartDistance
                self.session = updated
            }
            .store(in: &cancellables)
        
        locationService.$currentPace
            .sink { [weak self] pace in
                guard let self = self, let session = self.session else { return }
                let updated = session
                updated.state.currentPace = pace
                self.session = updated
            }
            .store(in: &cancellables)
    }
    
    func startWorkout(_ workout: Workout) async {
        print("=== WorkoutManager.startWorkout called ===")
        print("Workout: \(workout.name)")
        print("Thread: \(Thread.isMainThread ? "Main" : "Background")")
        
        // Debug: Print actual stored values
        print("DEBUG: Stored workout values:")
        print("  warmUpDuration: \(workout.warmUpDuration) minutes")
        print("  runIntervalDuration: \(workout.runIntervalDuration) minutes")
        print("  walkIntervalDuration: \(workout.walkIntervalDuration) minutes")
        print("  coolDownDuration: \(workout.coolDownDuration) minutes")
        
        // Validate workout
        guard workout.numberOfIntervals > 0 else {
            print("ERROR: Workout has no intervals")
            return
        }
        
        // Note: We normalize durations when converting to seconds, not here
        // This allows us to fix existing workouts without modifying the stored values
        
        print("Stopping any existing workout...")
        // Stop any existing workout first (this will reset isActive to false)
        if isActive {
            print("⚠️ Workout was already active, stopping it first...")
            stopWorkout()
            // Small delay to ensure stopWorkout completes
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Double-check after stopping
        guard !isActive else {
            print("ERROR: Workout still active after stopWorkout()")
            return
        }
        
        print("Creating new session...")
        // Create new session
        let newSession = WorkoutSession(workout: workout)
        let sessionCopy = newSession
        sessionCopy.startTime = Date()
        sessionCopy.state.isActive = true
        sessionCopy.state.currentIntervalType = .warmUp
        sessionCopy.state.intervalStartTime = Date()
        sessionCopy.state.remainingIntervals = workout.numberOfIntervals

        print("Session created, assigning to property...")
        session = sessionCopy
        isActive = true
        isPaused = false

        print("✓ Workout session created successfully")
        
        // Start location tracking (may request authorization)
        // This is non-blocking and will request permission if needed
        locationService.startTracking()
        
        // Start music if configured
        if musicService.currentProvider != .none {
            musicService.play()
        }
        
        // Start warm-up phase (or skip if duration is 0)
        if workout.warmUpDuration > 0 {
            print("Starting 10-second pre-warmup countdown")
            // Start 10-second countdown before warmup
            startPreWarmupCountdown { [weak self] in
                guard let self = self else { return }
                print("Pre-warmup countdown complete, announcing warm-up")
                // Announce warm-up AFTER countdown completes
                self.voiceService.announceWarmUp(duration: workout.warmUpDuration)
                
                // Start timer for warm-up
                // Direct multiplication: user input (minutes) × 60 = seconds
                let warmUpDuration = workout.warmUpDuration * 60
                print("Warm-up: \(workout.warmUpDuration) minutes = \(warmUpDuration) seconds")
                self.startIntervalTimer(duration: warmUpDuration) { [weak self] in
                    self?.transitionToIntervals()
                }
            }
        } else {
            print("Skipping warm-up, starting first run interval")
            // Skip warm-up and go straight to first running interval
            guard let currentSession = session else {
                print("ERROR: Session is nil when trying to skip warm-up")
                return
            }
            let updatedSession = currentSession
            updatedSession.state.currentIntervalType = .running
            updatedSession.state.currentIntervalIndex = 0
            intervalStartDistance = locationService.totalDistance
            session = updatedSession
            voiceService.announceIntervalStart(type: .running)
            // Direct multiplication: user input (minutes) × 60 = seconds
            let runDuration = workout.runIntervalDuration * 60
            print("Run: \(workout.runIntervalDuration) minutes = \(runDuration) seconds")
            startIntervalTimer(duration: runDuration) { [weak self] in
                self?.completeRunningInterval()
            }
        }
    }
    
    private func startIntervalTimer(duration: TimeInterval, completion: @escaping () -> Void) {
        guard var session = session else { 
            print("ERROR: Cannot start timer - no session")
            return 
        }
        
        // Invalidate any existing timer first
        timer?.invalidate()
        timer = nil
        
        // Reset elapsed time for this interval
        elapsedTime = 0
        countdownTriggered = false // Reset countdown flag for new interval
        session.state.elapsedTimeInCurrentInterval = 0
        session.state.intervalRemainingTime = duration // Set initial remaining time
        session.state.intervalStartTime = Date()
        self.session = session
        
        let intervalType = session.state.currentIntervalType
        let intervalInfo: String
        switch intervalType {
        case .warmUp:
            intervalInfo = "Warm-up"
        case .running:
            intervalInfo = "Run interval #\(session.state.currentIntervalIndex + 1)"
        case .walking:
            intervalInfo = "Walk interval #\(session.state.currentIntervalIndex + 1)"
        case .coolDown:
            intervalInfo = "Cool-down"
        }
        print("Starting interval timer for \(duration) seconds - \(intervalInfo)")
        
        // Store duration and completion for timer
        let targetDuration = duration
        let completionHandler = completion
        
        // Create timer using scheduledTimer which automatically adds to current RunLoop
        // Timer callbacks execute on the thread that scheduled them (main thread)
        // Wrap in Task to properly handle MainActor isolation
        let newTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Timer callback executes on main thread (since scheduled on main RunLoop)
            // Since WorkoutManager is @MainActor, we can access properties directly
            // Use MainActor.assumeIsolated to satisfy compiler while maintaining performance
            MainActor.assumeIsolated {
                // Ensure we're still active before updating
                guard self.isActive else {
                    print("WARNING: Timer fired but workout is not active, invalidating timer")
                    self.timer?.invalidate()
                    self.timer = nil
                    return
                }
                
                // Capture values we need
                let currentElapsed = self.elapsedTime + 1
                let currentTargetDuration = targetDuration
                let currentCompletionHandler = completionHandler
                
                // Update elapsed time
                self.elapsedTime = currentElapsed
                
                // Trigger countdown exactly 10 seconds before interval ends
                // Check if we're at exactly 10 seconds remaining (remaining time = 10 seconds)
                // For a 60-second interval, this should trigger at 50 seconds elapsed (60 - 10 = 50)
                let remainingTime = currentTargetDuration - currentElapsed
                // Use <= 10.0 to catch it even if timing is slightly off, but >= 9.0 to avoid triggering too early
                if remainingTime <= 10.0 && remainingTime >= 9.0 && !self.countdownTriggered {
                    self.countdownTriggered = true
                    print("Triggering 10-second countdown. Elapsed: \(Int(currentElapsed))s, Remaining: \(Int(remainingTime))s, Total: \(Int(currentTargetDuration))s")
                    self.startCountdown()
                }
                
                // Debug: print every 5 seconds with interval type info
                if Int(currentElapsed) % 5 == 0 {
                    let currentType = self.session?.state.currentIntervalType ?? .warmUp
                    let intervalNum = (self.session?.state.currentIntervalIndex ?? 0) + 1
                    print("Timer tick [\(currentType)]: \(Int(currentElapsed))s / \(Int(currentTargetDuration))s (Interval #\(intervalNum))")
                }
                
                // Update session state
                if let session = self.session {
                    session.state.elapsedTimeInCurrentInterval = currentElapsed
                    session.state.intervalRemainingTime = max(0, currentTargetDuration - currentElapsed)
                    session.state.totalElapsedTime += 1
                    self.session = session
                } else {
                    print("WARNING: Timer fired but session is nil")
                }
                
                // Check if interval is complete
                if currentElapsed >= currentTargetDuration {
                    print("Interval timer completed: \(currentElapsed) >= \(currentTargetDuration)")
                    self.timer?.invalidate()
                    self.timer = nil
                    currentCompletionHandler()
                }
            }
        }
        
        // Also add to common mode to ensure it fires during UI interactions
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
        
        print("Timer created and added to RunLoop. Timer valid: \(timer?.isValid ?? false), RunLoop: \(RunLoop.current == RunLoop.main)")
    }
    
    private func startCountdown() {
        guard isActive else {
            print("WARNING: Attempted to start countdown but workout is not active")
            return
        }
        
        guard var session = session else {
            print("WARNING: Attempted to start countdown but session is nil")
            return
        }
        
        let intervalType = session.state.currentIntervalType
        print("Starting countdown for \(intervalType.displayName). 10 seconds remaining")
        
        // Just announce "10 seconds remaining" once
        voiceService.countdown(seconds: 10) {
            print("Countdown completed, interval will transition soon")
            // Countdown completed, interval will transition when timer completes
        }
    }
    
    private func transitionToIntervals() {
        guard var session = session else { return }
        
        // Handle interval transitions
        if session.state.currentIntervalType == .warmUp {
            // Transition from warm-up to first running interval
            // Warm-up is NOT an interval - intervals are only run/walk pairs
            print("Warm-up complete. Starting first run interval")
            session.state.currentIntervalType = .running
            session.state.currentIntervalIndex = 0
            intervalStartDistance = locationService.totalDistance
            // Announce "Begin running" instead of "Begin running interval"
            voiceService.speak("Begin running")
            // Direct multiplication: user input (minutes) × 60 = seconds
            let runDuration = session.workout.runIntervalDuration * 60
            print("Run: \(session.workout.runIntervalDuration) minutes = \(runDuration) seconds")
            startIntervalTimer(duration: runDuration) { [weak self] in
                self?.completeRunningInterval()
            }
        } else if session.state.currentIntervalType == .running {
            // Transition from running to walking
            completeRunningInterval()
        } else if session.state.currentIntervalType == .walking {
            // Transition from walking to running or cool-down
            // Check if we've completed all intervals (each interval = run + walk)
            // currentIntervalIndex tracks which interval we're on (0-indexed)
            // After completing interval 0 (run+walk), we move to interval 1, etc.
            // We've completed all intervals when currentIntervalIndex >= numberOfIntervals
                        // Decrement remaining walk intervals when a walk completes
            print("Walk interval complete. Remaining walk intervals: \(session.state.remainingWalkIntervals) -> \(session.state.remainingWalkIntervals - 1)")
            session.state.remainingWalkIntervals = max(0, session.state.remainingWalkIntervals - 1)
            
            if session.state.currentIntervalIndex + 1 < session.workout.numberOfIntervals {
                // Start next interval (run phase)
                let nextIntervalIndex = session.state.currentIntervalIndex + 1
                print("Transitioning to run interval #\(nextIntervalIndex + 1)")
                session.state.currentIntervalIndex = nextIntervalIndex
                session.state.currentIntervalType = .running
                intervalStartDistance = locationService.totalDistance
            voiceService.announceIntervalStart(type: .running)
            // Direct multiplication: user input (minutes) × 60 = seconds
            let runDuration = session.workout.runIntervalDuration * 60
            print("Run: \(session.workout.runIntervalDuration) minutes = \(runDuration) seconds")
            startIntervalTimer(duration: runDuration) { [weak self] in
                self?.completeRunningInterval()
            }
            } else {
                // All intervals complete, start cool-down
                transitionToCoolDown()
            }
        }
        
        self.session = session
    }
    
    private func completeRunningInterval() {
        guard var session = session else { return }
        
        // Announce interval completion with stats
        let intervalDistance = locationService.totalDistance - intervalStartDistance
        let intervalPace = locationService.currentPace
        voiceService.announceIntervalComplete(
            type: .running,
            distance: intervalDistance,
            pace: intervalPace
        )
        
        session.state.currentIntervalType = .walking
        intervalStartDistance = locationService.totalDistance
        voiceService.announceIntervalStart(type: .walking)
        // Direct multiplication: user input (minutes) × 60 = seconds
        let walkDuration = session.workout.walkIntervalDuration * 60
        print("Walk: \(session.workout.walkIntervalDuration) minutes = \(walkDuration) seconds")
        startIntervalTimer(duration: walkDuration) { [weak self] in
            self?.transitionToIntervals()
        }
        
        self.session = session
    }
    
    private func transitionToCoolDown() {
        guard var session = session else { return }
        
        print("Transitioning to cool-down phase")
        session.state.currentIntervalType = .coolDown
        intervalStartDistance = locationService.totalDistance
        voiceService.announceCoolDown(duration: session.workout.coolDownDuration)
        
        // Start timer for cool-down (countdown will trigger 10 seconds before end)
        // Direct multiplication: user input (minutes) × 60 = seconds
        let coolDownDuration = session.workout.coolDownDuration * 60
        print("Cool-down: \(session.workout.coolDownDuration) minutes = \(coolDownDuration) seconds")
        startIntervalTimer(duration: coolDownDuration) { [weak self] in
            self?.completeWorkout()
        }
        
        self.session = session
    }
    
    private func completeWorkout() {
        guard var session = session else { return }
        
        session.endTime = Date()
        session.state.isActive = false
        isActive = false
        
        // Calculate average pace
        let totalDistance = locationService.totalDistance
        let totalTime = session.state.totalElapsedTime
        let averagePace = totalTime > 0 && totalDistance > 0 ? totalTime / totalDistance : nil
        
        // Create workout history entry
        let history = WorkoutHistory(
            workoutName: session.workout.name,
            startTime: session.startTime ?? Date(),
            endTime: session.endTime ?? Date(),
            totalDistance: totalDistance,
            averagePace: averagePace,
            totalDuration: totalTime
        )
        
        completedWorkout = history
        
        // Stop location tracking
        locationService.stopTracking()
        
        // Announce completion
        voiceService.announceWorkoutComplete(
            totalDistance: totalDistance,
            totalTime: totalTime
        )
        
        // Pause music
        musicService.pause()
        
        timer?.invalidate()
        timer = nil
        
        self.session = session
    }
    
    func pauseWorkout() {
        guard isActive, !isPaused else { return }
        
        isPaused = true
        timer?.invalidate()
        timer = nil
        
        // Stop voice commands when pausing
        voiceService.stopSpeaking()
        
        if let session = session {
            session.state.isPaused = true
            self.session = session
        }
    }
    
    func resumeWorkout() {
        guard isActive, isPaused else { return }
        
        isPaused = false
        
        if let session = session {
            let updatedSession = session
            updatedSession.state.isPaused = false
            
            // Resume timer based on current interval
            let remainingTime = getRemainingTimeInCurrentInterval()
            if remainingTime > 0 {
                startIntervalTimer(duration: remainingTime) { [weak self] in
                    self?.transitionToIntervals()
                }
            }
            
            self.session = updatedSession
        }
    }
    
    private func getRemainingTimeInCurrentInterval() -> TimeInterval {
        guard var session = session,
              let intervalStartTime = session.state.intervalStartTime else {
            return 0
        }
        
        let elapsed = Date().timeIntervalSince(intervalStartTime)
        let totalDuration: TimeInterval
        
        switch session.state.currentIntervalType {
        case .warmUp:
            totalDuration = session.workout.warmUpDuration * 60
        case .running:
            totalDuration = session.workout.runIntervalDuration * 60
        case .walking:
            totalDuration = session.workout.walkIntervalDuration * 60
        case .coolDown:
            totalDuration = session.workout.coolDownDuration * 60
        }
        
        return max(0, totalDuration - elapsed)
    }
    
    private func startPreWarmupCountdown(completion: @escaping () -> Void) {
        // Start with 10 displayed immediately
        preWarmupCountdown = 10
        
        // Countdown from 10 to 0, showing each number for 1 second
        var countdownValue = 9 // Next value to show (after 10)
        
        func updateCountdown() {
            guard isActive else {
                preWarmupCountdown = nil
                return
            }
            
            if countdownValue >= 0 {
                // Update the displayed value
                preWarmupCountdown = countdownValue
                countdownValue -= 1
                // Schedule next update after 1 second
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    updateCountdown()
                }
            } else {
                // Countdown complete (we've shown 0)
                preWarmupCountdown = nil
                completion()
            }
        }
        
        // Start the countdown after 1 second (so 10 shows for 1 second)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            updateCountdown()
        }
    }
    
    func stopWorkout() {
        print("stopWorkout called")
        
        // Invalidate timers synchronously on main thread
        timer?.invalidate()
        timer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        elapsedTime = 0
        
        // Stop pre-warmup countdown if active
        preWarmupCountdown = nil
        
        locationService.stopTracking()
        voiceService.stopSpeaking()
        musicService.pause()
        
        isActive = false
        isPaused = false
        completedWorkout = nil // Don't save stopped workouts
        session = nil
        
        print("Workout stopped successfully")
    }
}

