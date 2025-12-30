//
//  LiveWorkoutView.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import SwiftUI
import SwiftData

struct LiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workoutPresentationManager: WorkoutPresentationManager
    @StateObject private var workoutManager = WorkoutManager.shared
    
    let workout: Workout
    let musicProvider: MusicProvider
    
    @State private var hasError = false
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var showStopConfirmation = false
    @State private var showPausedMessage = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Black background
                Color.black
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Starting workout...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isLoading = false
                            }
                        }
                } else if let session = workoutManager.session {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Current Interval Display
                            IntervalProgressView(session: session)
                            
                            // Interval Labels and Large Countdown Timer
                            VStack(spacing: 8) {
                                // Run and Walk interval labels
                                // Both show remaining intervals (starts at max, decreases by 1 for each completed interval pair)
                                HStack {
                                    Text("Run Interval \(session.state.remainingRunIntervals)")
                                        .font(.headline)
                                        .foregroundColor(session.state.currentIntervalType == .running ? .white : .blue.opacity(0.6))
                                        .bold(session.state.currentIntervalType == .running)
                                    Spacer()
                                    Text("Walk Interval \(session.state.remainingWalkIntervals)")
                                        .font(.headline)
                                        .foregroundColor(session.state.currentIntervalType == .walking ? .white : .orange.opacity(0.6))
                                        .bold(session.state.currentIntervalType == .walking)
                                }
                                .padding(.horizontal)
                                
                                TimerView(session: session)
                            }
                            
                            // Stats Grid
                            StatsView(session: session)
                            
                            // Overall Progress
                            OverallProgressView(session: session)
                            
                            // Controls
                            WorkoutControls(
                                showStopConfirmation: $showStopConfirmation,
                                showPausedMessage: $showPausedMessage
                            )
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Text("Failed to start workout")
                            .font(.title)
                            .foregroundColor(.white)
                        Button("Dismiss") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        stopWorkoutAndDismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        // Swipe down gesture
                        if value.translation.height > 0 && abs(value.translation.height) > abs(value.translation.width) {
                            stopWorkoutAndDismiss()
                        }
                    }
            )
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)
                await workoutManager.startWorkout(workout)
            }
        }
        .alert("Stop Workout", isPresented: $showStopConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                workoutManager.stopWorkout()
                workoutPresentationManager.dismissWorkout()
                // Navigate back to main page
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to stop this workout? Your progress will be saved.")
        }
        .alert("Workout Paused", isPresented: $showPausedMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your workout has been paused. Tap Resume to continue.")
        }
        .alert("Error", isPresented: $hasError) {
            Button("OK", action: { dismiss() })
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }
    
    private func stopWorkoutAndDismiss() {
        workoutManager.stopWorkout()
        workoutPresentationManager.dismissWorkout()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

// MARK: - Interval Progress View

struct IntervalProgressView: View {
    @ObservedObject var session: WorkoutSession
    
    var body: some View {
        VStack(spacing: 16) {
            Text(session.state.currentIntervalType.displayName)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            // Interval progress bar
            ProgressView(
                value: Double(session.state.currentIntervalIndex + 1),
                total: Double(session.workout.numberOfIntervals)
            )
            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            .frame(height: 8)
            
            Text("Interval \(session.state.currentIntervalIndex + 1) of \(session.workout.numberOfIntervals)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

// MARK: - Timer View

struct TimerView: View {
    @ObservedObject var session: WorkoutSession
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Time Remaining")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(formatTime(session.state.intervalRemainingTime))
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding()
    }
    
    func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Stats View

struct StatsView: View {
    @ObservedObject var session: WorkoutSession
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCardDark(
                title: "Total Distance",
                value: formatDistance(session.state.totalDistance),
                icon: "ruler"
            )
            
            StatCardDark(
                title: "Current Pace",
                value: formatPace(session.state.currentPace),
                icon: "speedometer"
            )
            
            StatCardDark(
                title: "Interval Distance",
                value: formatDistance(session.state.intervalDistance),
                icon: "figure.run"
            )
            
            StatCardDark(
                title: "Total Time",
                value: formatTime(session.state.totalElapsedTime),
                icon: "clock"
            )
        }
        .padding(.horizontal)
    }
    
    func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.34
        return String(format: "%.2f mi", miles)
    }
    
    func formatPace(_ paceSecondsPerMeter: Double?) -> String {
        guard let pace = paceSecondsPerMeter else {
            return "--:--/mi"
        }
        let pacePerMile = pace * 1609.34
        let minutesPerMile = pacePerMile / 60.0
        let minutes = Int(minutesPerMile)
        let seconds = Int((minutesPerMile - Double(minutes)) * 60)
        return String(format: "%d:%02d/mi", minutes, seconds)
    }
    
    func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Overall Progress View

struct OverallProgressView: View {
    @ObservedObject var session: WorkoutSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Workout Progress")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(calculateProgress() * 100))%")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            
            ProgressView(value: calculateProgress())
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .frame(height: 8)
            
            Text("Remaining: \(formatRemainingTime())")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
    
    private func calculateProgress() -> Double {
        let totalDuration = session.workout.totalDuration * 60 // Convert minutes to seconds
        guard totalDuration > 0 else { return 0 }
        return min(1.0, session.state.totalElapsedTime / totalDuration)
    }
    
    private func formatRemainingTime() -> String {
        let totalDuration = session.workout.totalDuration * 60
        let remaining = max(0, totalDuration - session.state.totalElapsedTime)
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Workout Controls

struct WorkoutControls: View {
    @StateObject private var workoutManager = WorkoutManager.shared
    @Binding var showStopConfirmation: Bool
    @Binding var showPausedMessage: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            if workoutManager.isPaused {
                Button(action: {
                    workoutManager.resumeWorkout()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Resume")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            } else {
                Button(action: {
                    workoutManager.pauseWorkout()
                    showPausedMessage = true
                }) {
                    HStack {
                        Image(systemName: "pause.fill")
                        Text("Pause")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            Button(action: {
                showStopConfirmation = true
            }) {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Stop")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
}
