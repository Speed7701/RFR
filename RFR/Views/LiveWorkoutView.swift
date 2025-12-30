import SwiftUI
import SwiftData

struct LiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var workoutManager = WorkoutManager.shared
    
    let workout: Workout
    let musicProvider: MusicProvider
    
    @State private var hasError = false
    @State private var errorMessage: String?
    @State private var isLoading = true  // CRITICAL: Loading state
    
    var body: some View {
        NavigationStack {  // CRITICAL FIX #2: Wrap in NavigationStack
            VStack {
                if isLoading {
                    ProgressView("Starting workout...")
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isLoading = false
                            }
                        }
                } else if let session = workoutManager.session {
                    // ✅ Your main workout UI here
                    VStack {
                        // Interval progress
                        IntervalProgressView(session: session)

                        // Timer display
                        TimerView(elapsed: session.state.elapsedTimeInCurrentInterval)

                        // Distance & pace
                        StatsView(
                            distance: session.state.totalDistance,
                            pace: session.state.currentPace
                        )

                        // Controls
                        WorkoutControls()
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                        Text("Failed to start workout")
                        Button("Dismiss", action: { dismiss() })
                    }
                    .onAppear {
                        hasError = true
                        errorMessage = "Workout session failed to initialize"
                    }
                }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            await MainActor.run {
                workoutManager.startWorkout(workout)
            }
        }
        .onDisappear {
            workoutManager.stopWorkout()
        }
        .alert("Error", isPresented: $hasError) {
            Button("OK", action: { dismiss() })
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }
}

// MARK: - Supporting Views
struct IntervalProgressView: View {
    @ObservedObject var session: WorkoutSession
    
    var body: some View {
        VStack {
            Text(session.state.currentIntervalType.displayName)
                .font(.largeTitle.bold())
            
            ProgressView(
                value: Double(session.state.currentIntervalIndex + 1),
                total: Double(session.workout.numberOfIntervals)
            )
            .padding()
        }
    }
}

struct TimerView: View {
    let elapsed: TimeInterval
    
    var body: some View {
        Text(formatTime(elapsed))
            .font(.system(size: 60, weight: .bold, design: .monospaced))
    }
    
    func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

struct StatsView: View {
    let distance: Double
    let pace: Double?
    
    var body: some View {
        HStack(spacing: 40) {
            VStack {
                Text(String(format: "%.2f", distance / 1609.34))
                    .font(.title2.bold())
                Text("miles")
                    .font(.caption)
            }
            
            if let pace = pace {
                VStack {
                    Text(formatPace(pace))
                        .font(.title2.bold())
                    Text("pace")
                        .font(.caption)
                }
            }
        }
    }
    
    func formatPace(_ secondsPerMeter: Double) -> String {
        let minutesPerMile = (secondsPerMeter * 1609.34) / 60
        let minutes = Int(minutesPerMile)
        let seconds = Int((minutesPerMile - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct WorkoutControls: View {
    @StateObject private var workoutManager = WorkoutManager.shared
    
    var body: some View {
        HStack(spacing: 30) {
            if workoutManager.isPaused {
                Button("Resume") {
                    workoutManager.resumeWorkout()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Pause") {
                    workoutManager.pauseWorkout()
                }
                .buttonStyle(.bordered)
            }
            
            Button("Stop") {
                workoutManager.stopWorkout()
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
    }
}
