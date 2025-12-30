//
//  DashboardView.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutHistory.startTime, order: .reverse) private var workoutHistory: [WorkoutHistory]
    @EnvironmentObject private var workoutPresentationManager: WorkoutPresentationManager
    @Query(sort: \Workout.createdAt, order: .reverse) private var workouts: [Workout]
    
    @State private var selectedTab: TabSelection = .dashboard
    @State private var hasError = false
    @State private var errorMessage: String?
    
    enum TabSelection: String {
        case dashboard = "Main"
        case workouts = "Workout"
        case statistics = "Statistics"
    }
    
    var body: some View {
        Group {
            if hasError {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Error Loading App")
                        .font(.title)
                    if let error = errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    Button("Retry") {
                        hasError = false
                        errorMessage = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                TabView(selection: $selectedTab) {
                    // Main/Dashboard Tab
                    NavigationStack {
                        ScrollView {
                            VStack(spacing: 24) {
                                // Header with Logo
                                VStack(spacing: 8) {
                                    RFRLogoView()
                                        .frame(width: 80, height: 80)
                                    
                                    Text("RFR Swift")
                                        .font(.title)
                                        .bold()
                                    
                                    Text("Running Interval Trainer")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top)
                        
                        // Weekly Stats
                        VStack(alignment: .leading, spacing: 16) {
                            Text("This Week")
                                .font(.title2)
                                .bold()
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                StatCard(
                                    title: "Workouts",
                                    value: "\(weeklyWorkoutCount)",
                                    icon: "figure.run",
                                    color: .blue
                                )
                                
                                StatCard(
                                    title: "Distance",
                                    value: formatDistance(weeklyDistance),
                                    icon: "ruler",
                                    color: .green
                                )
                                
                                StatCard(
                                    title: "Avg Pace",
                                    value: formatPace(weeklyAveragePace),
                                    icon: "speedometer",
                                    color: .orange
                                )
                                
                                StatCard(
                                    title: "Time",
                                    value: formatTime(weeklyTotalTime),
                                    icon: "clock",
                                    color: .purple
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Recent Workouts
                        if !recentWorkouts.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent Workouts")
                                    .font(.title2)
                                    .bold()
                                    .padding(.horizontal)
                                
                                ForEach(recentWorkouts.prefix(5)) { workout in
                                    WorkoutHistoryRow(workout: workout)
                                        .padding(.horizontal)
                                }
                            }
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                
                                Text("No workouts yet")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Create and start your first workout!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Quick Actions
                        VStack(spacing: 12) {
                            Button(action: { selectedTab = .workouts }) {
                                HStack {
                                    Image(systemName: "list.bullet")
                                    Text("View All Workouts")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            
                            NavigationLink(destination: WorkoutCreationView()) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create New Workout")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
                .navigationTitle("Main")
                .refreshable {
                    // Refresh data if needed
                }
            }
            .tabItem {
                Label("Main", systemImage: "house.fill")
            }
            .tag(TabSelection.dashboard)
            
            // Workout Tab
                            WorkoutListView()
                .environmentObject(workoutPresentationManager)
                .tabItem {
                    Label("Workout", systemImage: "figure.run")
                }
                .tag(TabSelection.workouts)
            
            // Statistics Tab
            StatisticsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }
                .tag(TabSelection.statistics)
        }
        }
    }
        .task {
            // Verify modelContext is available
            print("DashboardView: Checking modelContext...")
            do {
                let testFetch = FetchDescriptor<Workout>()
                _ = try modelContext.fetch(testFetch)
                print("DashboardView: modelContext is working")
            } catch {
                print("DashboardView: ModelContext error: \(error)")
                await MainActor.run {
                    hasError = true
                    errorMessage = "Database error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var weeklyWorkouts: [WorkoutHistory] {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        return workoutHistory.filter { workout in
            workout.startTime >= weekAgo
        }
    }
    
    private var weeklyWorkoutCount: Int {
        weeklyWorkouts.count
    }
    
    private var weeklyDistance: Double {
        weeklyWorkouts.reduce(0) { $0 + $1.totalDistance }
    }
    
    private var weeklyAveragePace: Double? {
        let paces = weeklyWorkouts.compactMap { $0.averagePace }
        guard !paces.isEmpty else { return nil }
        return paces.reduce(0, +) / Double(paces.count)
    }
    
    private var weeklyTotalTime: TimeInterval {
        weeklyWorkouts.reduce(0) { $0 + $1.totalDuration }
    }
    
    private var recentWorkouts: [WorkoutHistory] {
        Array(workoutHistory.prefix(10))
    }
    
    // MARK: - Formatting
    
    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.34
        if miles >= 0.1 {
            return String(format: "%.2f mi", miles)
        } else {
            return String(format: "%.2f km", meters / 1000.0)
        }
    }
    
    private func formatPace(_ paceSecondsPerMeter: Double?) -> String {
        guard let pace = paceSecondsPerMeter else {
            return "--:--"
        }
        
        let pacePerMile = pace * 1609.34
        let minutesPerMile = pacePerMile / 60.0
        
        let minutes = Int(minutesPerMile)
        let seconds = Int((minutesPerMile - Double(minutes)) * 60)
        
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}


struct WorkoutHistoryRow: View {
    let workout: WorkoutHistory
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workoutName)
                    .font(.headline)
                
                Text(workout.startTime, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDistance(workout.totalDistance))
                    .font(.headline)
                
                if let pace = workout.averagePace {
                    Text(formatPace(pace))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.34
        return String(format: "%.2f mi", miles)
    }
    
    private func formatPace(_ paceSecondsPerMeter: Double) -> String {
        let pacePerMile = paceSecondsPerMeter * 1609.34
        let minutesPerMile = pacePerMile / 60.0
        
        let minutes = Int(minutesPerMile)
        let seconds = Int((minutesPerMile - Double(minutes)) * 60)
        
        return String(format: "%d:%02d/mi", minutes, seconds)
    }
}

struct RFRLogoView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("RFR")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Workout.self, WorkoutHistory.self], inMemory: true)
}

