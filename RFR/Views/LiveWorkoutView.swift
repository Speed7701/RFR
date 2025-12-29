//
//  LiveWorkoutView.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import SwiftUI
import SwiftData

struct LiveWorkoutView: View {
    let workout: Workout
    let musicProvider: MusicProvider
    
    // Use environment but provide fallback
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    // Access singletons safely - they're already initialized as static let shared
    @ObservedObject private var workoutManager: WorkoutManager = {
        print("=== Accessing WorkoutManager.shared ===")
        return WorkoutManager.shared
    }()
    @ObservedObject private var locationService: LocationService = {
        print("=== Accessing LocationService.shared ===")
        return LocationService.shared
    }()
    @ObservedObject private var musicService: MusicService = {
        print("=== Accessing MusicService.shared ===")
        return MusicService.shared
    }()
    @State private var showingStopConfirmation = false
    @State private var hasSavedHistory = false
    @State private var errorMessage: String?
    @State private var isInitialized = false
    
    init(workout: Workout, musicProvider: MusicProvider) {
        self.workout = workout
        self.musicProvider = musicProvider
        print("=== LiveWorkoutView.init called ===")
        print("Workout: \(workout.name)")
        print("Music provider: \(musicProvider.rawValue)")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // Pre-warmup countdown overlay
                if let countdown = workoutManager.preWarmupCountdown {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        
                        VStack {
                            Text("\(countdown)")
                                .font(.system(size: 200, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()
                            
                            Text("Starting warmup")
                                .font(.title2)
                                .foregroundColor(.gray)
                                .padding(.top, 20)
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1000)
                }
                
                VStack(spacing: 30) {
                    // Interval Type Indicator
                    if let session = workoutManager.session {
                        VStack(spacing: 8) {
                            Text(session.state.currentIntervalType.emoji)
                                .font(.system(size: 60))
                            
                            Text(session.state.currentIntervalType.displayName)
                                .font(.title)
                                .bold()
                                .foregroundColor(.white)
                            
                            if session.state.remainingIntervals > 0 && session.state.currentIntervalType != .warmUp && session.state.currentIntervalType != .coolDown {
                                Text("\(session.state.remainingIntervals) interval\(session.state.remainingIntervals == 1 ? "" : "s") remaining")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 40)
                    } else {
                        // Loading state while workout initializes
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Starting workout...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 40)
                    }
                    
                    Spacer()
                
                // Timer Display
                if let session = workoutManager.session {
                    VStack(spacing: 16) {
                        Text("Current Interval")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text(formatTime(session.state.elapsedTimeInCurrentInterval))
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                        
                        Text("Total Time: \(formatTime(session.state.totalElapsedTime))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    // Placeholder for timer when loading
                    VStack(spacing: 16) {
                        Text("Current Interval")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("00:00")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.3))
                            .monospacedDigit()
                        
                        Text("Total Time: 00:00")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Stats Grid
                if let session = workoutManager.session {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        StatCardDark(
                            title: "Distance",
                            value: formatDistance(session.state.totalDistance),
                            icon: "figure.run"
                        )
                        
                        StatCardDark(
                            title: "Pace",
                            value: formatPace(session.state.currentPace),
                            icon: "speedometer"
                        )
                        
                        StatCardDark(
                            title: "Interval Distance",
                            value: formatDistance(session.state.intervalDistance),
                            icon: "ruler"
                        )
                        
                        StatCardDark(
                            title: "Current Interval",
                            value: formatCurrentInterval(session),
                            icon: session.state.currentIntervalType.icon
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Progress Bar
                if let session = workoutManager.session {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progress")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(width: geometry.size.width * workoutProgress, height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal)
                } else {
                    // Placeholder progress bar
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progress")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Control Buttons
                HStack(spacing: 30) {
                    if workoutManager.isPaused {
                        Button(action: { workoutManager.resumeWorkout() }) {
                            Image(systemName: "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.green)
                                .clipShape(Circle())
                        }
                    } else {
                        Button(action: { workoutManager.pauseWorkout() }) {
                            Image(systemName: "pause.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.orange)
                                .clipShape(Circle())
                        }
                    }
                    
                    Button(action: { showingStopConfirmation = true }) {
                        Image(systemName: "stop.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 40)
            }
        }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            print("=== LiveWorkoutView.onAppear called ===")
            
            // Prevent multiple initializations
            guard !isInitialized else {
                print("View already initialized, skipping")
                return
            }
            
            isInitialized = true
            
            // Start workout when view appears
            // Validate workout before starting
            guard workout.warmUpDuration > 0 || workout.numberOfIntervals > 0 else {
                print("ERROR: Invalid workout configuration")
                errorMessage = "Invalid workout configuration"
                return
            }
            
            print("Setting music provider...")
            // Set music provider first
            musicService.currentProvider = musicProvider
            
            print("Requesting location authorization...")
            // Request location authorization (non-blocking)
            locationService.requestAuthorization()
            
            print("Scheduling workout start...")
            // Start workout synchronously on main thread to avoid cancellation
            // Use a small delay to ensure view is fully rendered
            // Note: SwiftUI views are structs, so we capture workoutManager and workout directly
            let manager = workoutManager
            let workoutToStart = workout
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("=== LiveWorkoutView: Starting workout on main thread ===")
                print("Workout name: \(workoutToStart.name)")
                print("Workout intervals: \(workoutToStart.numberOfIntervals)")
                print("Warm-up duration: \(workoutToStart.warmUpDuration)")
                print("Thread: \(Thread.isMainThread ? "Main" : "Background")")
                
                // startWorkout doesn't throw, so no need for do-catch
                manager.startWorkout(workoutToStart)
                print("=== Workout start call completed ===")
            }
        }
        .onDisappear {
            // Don't stop workout if it's still active (user might be navigating)
            // Only stop if explicitly stopped
        }
        .onChange(of: workoutManager.completedWorkout) { oldValue, newValue in
            if let completedWorkout = newValue, !hasSavedHistory {
                // Only save if modelContext is available
                do {
                    modelContext.insert(completedWorkout)
                    try modelContext.save()
                    hasSavedHistory = true
                    // Dismiss after a short delay to allow user to see completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                } catch {
                    print("Failed to save workout history: \(error.localizedDescription)")
                    // Don't show error if modelContext isn't available - just log it
                    errorMessage = "Workout completed but history not saved"
                }
            }
        }
        .onChange(of: workoutManager.isActive) { oldValue, newValue in
            if !newValue && !hasSavedHistory, let completedWorkout = workoutManager.completedWorkout {
                do {
                    modelContext.insert(completedWorkout)
                    try modelContext.save()
                    hasSavedHistory = true
                } catch {
                    print("Failed to save workout history: \(error)")
                    errorMessage = "Failed to save workout history"
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .alert("Stop Workout?", isPresented: $showingStopConfirmation) {
            Button("Cancel", role: .cancel) { 
                showingStopConfirmation = false
            }
            Button("Stop", role: .destructive) {
                workoutManager.stopWorkout()
                showingStopConfirmation = false
                // Dismiss and return to main page
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to stop this workout? Your progress will not be saved.")
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Stop") {
                    showingStopConfirmation = true
                }
                .foregroundColor(.red)
            }
        }
    }
    
    private var workoutProgress: Double {
        guard let session = workoutManager.session else { return 0 }
        
        let totalDuration = workout.totalDuration * 60 // Convert to seconds
        guard totalDuration > 0 else { return 0 }
        
        return min(1.0, session.state.totalElapsedTime / totalDuration)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.34
        let km = meters / 1000.0
        
        // Use miles if >= 0.1 miles, otherwise use meters/km
        if miles >= 0.1 {
            return String(format: "%.2f mi", miles)
        } else if km >= 0.1 {
            return String(format: "%.2f km", km)
        } else {
            return String(format: "%.0f m", meters)
        }
    }
    
    private func formatPace(_ paceSecondsPerMeter: Double?) -> String {
        guard let pace = paceSecondsPerMeter else {
            return "--:--"
        }
        
        let pacePerMile = pace * 1609.34 // seconds per mile
        let minutesPerMile = pacePerMile / 60.0
        
        let minutes = Int(minutesPerMile)
        let seconds = Int((minutesPerMile - Double(minutes)) * 60)
        
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatCurrentInterval(_ session: WorkoutSession) -> String {
        let intervalType = session.state.currentIntervalType
        
        switch intervalType {
        case .warmUp:
            return "Warm-up"
        case .running:
            // Intervals are only run/walk pairs, so show interval number (currentIntervalIndex is 0-indexed)
            let intervalNumber = session.state.currentIntervalIndex + 1
            return "Interval \(intervalNumber) - Run"
        case .walking:
            // Intervals are only run/walk pairs, so show interval number (currentIntervalIndex is 0-indexed)
            let intervalNumber = session.state.currentIntervalIndex + 1
            return "Interval \(intervalNumber) - Walk"
        case .coolDown:
            return "Cool-down"
        }
    }
}


#Preview {
    NavigationStack {
        LiveWorkoutView(
            workout: Workout(
                name: "Test",
                warmUpDuration: 5,
                runIntervalDuration: 2,
                walkIntervalDuration: 1,
                numberOfIntervals: 5,
                coolDownDuration: 5
            ),
            musicProvider: .none
        )
    }
}

