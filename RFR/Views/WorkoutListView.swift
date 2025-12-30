//
//  WorkoutListView.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import SwiftUI
import SwiftData

struct WorkoutListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var workoutPresentationManager: WorkoutPresentationManager
    @Query(sort: \Workout.createdAt, order: .reverse) private var workouts: [Workout]
    @State private var showingCreateWorkout = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(workouts) { workout in
                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                        WorkoutRowView(workout: workout)
                    }
                }
                .onDelete(perform: deleteWorkouts)
            }
            .navigationTitle("RFR Swift")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateWorkout = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateWorkout) {
                WorkoutCreationView()
            }
        }
    }
    
    private func deleteWorkouts(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(workouts[index])
            }
        }
    }
}

struct WorkoutRowView: View {
    let workout: Workout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.name)
                .font(.headline)
            
            HStack {
                Label("\(workout.numberOfIntervals) intervals", systemImage: "repeat")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatDuration(workout.totalDuration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

struct WorkoutDetailView: View {
    let workout: Workout
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workoutPresentationManager: WorkoutPresentationManager
    @State private var showingStartConfirmation = false
    @State private var selectedMusicProvider: MusicProvider = .none
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Workout Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Workout Details")
                        .font(.title2)
                        .bold()
                    
                    DetailRow(label: "Warm-up", value: formatMinutes(workout.warmUpDuration))
                    DetailRow(label: "Run Duration", value: formatMinutes(workout.runIntervalDuration))
                    DetailRow(label: "Walk Duration", value: formatMinutes(workout.walkIntervalDuration))
                    DetailRow(label: "Number of Intervals", value: "\(workout.numberOfIntervals)")
                    DetailRow(label: "Interval Time", value: formatMinutes(workout.runIntervalDuration + workout.walkIntervalDuration))
                    DetailRow(label: "Cool-down", value: formatMinutes(workout.coolDownDuration))
                    DetailRow(label: "Total Duration", value: formatDuration(workout.totalDuration))
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Start Button
                Button(action: { showingStartConfirmation = true }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Workout")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // Delete Button
                Button(action: { showingDeleteConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Workout")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingStartConfirmation) {
            WorkoutStartView(
                workout: workout,
                onStart: { provider in
                    selectedMusicProvider = provider
                    showingStartConfirmation = false
                    // Use the presentation manager
                    workoutPresentationManager.presentWorkout(workout, musicProvider: provider)
                    // Dismiss this view
                    dismiss()
                }
            )
        }

        .alert("Delete Workout", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteWorkout()
            }
        } message: {
            Text("Are you sure you want to delete \"\(workout.name)\"? This action cannot be undone.")
        }
    }
    
    private func deleteWorkout() {
        modelContext.delete(workout)
        dismiss()
    }
    
    private func formatMinutes(_ minutes: Double) -> String {
        let mins = Int(minutes)
        return "\(mins) min\(mins == 1 ? "" : "s")"
    }
    
    private func formatDuration(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

#Preview {
    WorkoutListView()
        .modelContainer(for: Workout.self, inMemory: true)
}

