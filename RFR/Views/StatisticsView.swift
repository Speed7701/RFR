//
//  StatisticsView.swift
//  RFR
//
//  Created by Anthony Swan on 30/12/2025.
//

import SwiftUI
import SwiftData
#if canImport(Charts)
import Charts
#endif

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutHistory.startTime, order: .reverse) private var workoutHistory: [WorkoutHistory]
    
    @State private var selectedTimeframe: Timeframe = .allTime
    
    enum Timeframe: String, CaseIterable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case allTime = "All Time"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Timeframe Picker
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Overall Stats Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatisticsStatCard(
                            title: "Total Workouts",
                            value: "\(filteredWorkouts.count)",
                            icon: "figure.run",
                            color: .blue
                        )
                        
                        StatisticsStatCard(
                            title: "Total Distance",
                            value: formatDistance(totalDistance),
                            icon: "ruler",
                            color: .green
                        )
                        
                        StatisticsStatCard(
                            title: "Total Time",
                            value: formatTime(totalTime),
                            icon: "clock",
                            color: .purple
                        )
                        
                        StatisticsStatCard(
                            title: "Avg Pace",
                            value: formatPace(averagePace),
                            icon: "speedometer",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // Progress Chart Section
                    ProgressChartSection(workouts: filteredWorkouts)
                    
                    // Insights Section
                    InsightsSection(workouts: filteredWorkouts)
                    
                    // Detailed Workout History
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Workout History")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        if filteredWorkouts.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "chart.bar")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                
                                Text("No workouts yet")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Complete workouts to see your statistics here")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(filteredWorkouts) { workout in
                                WorkoutHistoryRow(workout: workout)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("Statistics")
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredWorkouts: [WorkoutHistory] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeframe {
        case .thisWeek:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return workoutHistory.filter { $0.startTime >= weekAgo }
        case .thisMonth:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return workoutHistory.filter { $0.startTime >= monthAgo }
        case .allTime:
            return workoutHistory
        }
    }
    
    private var totalDistance: Double {
        filteredWorkouts.reduce(0) { $0 + $1.totalDistance }
    }
    
    private var totalTime: TimeInterval {
        filteredWorkouts.reduce(0) { $0 + $1.totalDuration }
    }
    
    private var averagePace: Double? {
        let paces = filteredWorkouts.compactMap { $0.averagePace }
        guard !paces.isEmpty else { return nil }
        return paces.reduce(0, +) / Double(paces.count)
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
        
        return String(format: "%d:%02d/mi", minutes, seconds)
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

// MARK: - Statistics Stat Card

struct StatisticsStatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .accentColor
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Progress Chart Section

struct ProgressChartSection: View {
    let workouts: [WorkoutHistory]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distance Over Time")
                .font(.title2)
                .bold()
                .padding(.horizontal)
            
            if #available(iOS 16.0, *) {
                ChartView(workouts: workouts)
                    .frame(height: 200)
                    .padding(.horizontal)
            } else {
                SimpleBarChart(workouts: workouts)
                    .frame(height: 200)
                    .padding(.horizontal)
            }
        }
    }
}

@available(iOS 16.0, *)
struct ChartView: View {
    let workouts: [WorkoutHistory]
    
    var body: some View {
        Chart {
            ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                BarMark(
                    x: .value("Workout", index + 1),
                    y: .value("Distance", workout.totalDistance / 1609.34)
                )
                .foregroundStyle(.blue.gradient)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.1f", doubleValue))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
}

struct SimpleBarChart: View {
    let workouts: [WorkoutHistory]
    
    var body: some View {
        // Precompute values outside the view builder to avoid non-View statements inside VStack
        let maxDistance = max(workouts.map { $0.totalDistance }.max() ?? 0, 1)
        let items = Array(workouts.prefix(10).enumerated())
        
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.element.id) { index, workout in
                HStack(spacing: 8) {
                    Text("#\(index + 1)")
                        .font(.caption)
                        .frame(width: 30)
                    
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.blue.gradient)
                                .frame(width: geometry.size.width * CGFloat(workout.totalDistance / maxDistance))
                            
                            Spacer()
                        }
                    }
                    .frame(height: 20)
                    
                    Text(String(format: "%.2f mi", workout.totalDistance / 1609.34))
                        .font(.caption)
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Insights Section

struct InsightsSection: View {
    let workouts: [WorkoutHistory]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.title2)
                .bold()
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                InsightRow(
                    icon: "flame.fill",
                    title: "Current Streak",
                    value: "\(currentStreak) days",
                    color: .orange
                )
                
                InsightRow(
                    icon: "clock.fill",
                    title: "Longest Workout",
                    value: formatTime(longestWorkout),
                    color: .purple
                )
                
                InsightRow(
                    icon: "ruler.fill",
                    title: "Farthest Run",
                    value: formatDistance(farthestRun),
                    color: .green
                )
                
                InsightRow(
                    icon: "speedometer",
                    title: "Fastest Pace",
                    value: formatPace(fastestPace),
                    color: .blue
                )
            }
            .padding(.horizontal)
        }
    }
    
    private var currentStreak: Int {
        guard !workouts.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        let sortedWorkouts = workouts.sorted { $0.startTime > $1.startTime }
        
        for workout in sortedWorkouts {
            let workoutDate = calendar.startOfDay(for: workout.startTime)
            
            if workoutDate == currentDate {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if workoutDate < currentDate {
                break
            }
        }
        
        return streak
    }
    
    private var longestWorkout: TimeInterval {
        workouts.map { $0.totalDuration }.max() ?? 0
    }
    
    private var farthestRun: Double {
        workouts.map { $0.totalDistance }.max() ?? 0
    }
    
    private var fastestPace: Double? {
        workouts.compactMap { $0.averagePace }.min()
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.34
        return String(format: "%.2f mi", miles)
    }
    
    private func formatPace(_ paceSecondsPerMeter: Double?) -> String {
        guard let pace = paceSecondsPerMeter else {
            return "--:--/mi"
        }
        
        let pacePerMile = pace * 1609.34
        let minutesPerMile = pacePerMile / 60.0
        
        let minutes = Int(minutesPerMile)
        let seconds = Int((minutesPerMile - Double(minutes)) * 60)
        
        return String(format: "%d:%02d/mi", minutes, seconds)
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

struct InsightRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.headline)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [WorkoutHistory.self], inMemory: true)
}

