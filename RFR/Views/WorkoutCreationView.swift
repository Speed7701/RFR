//
//  WorkoutCreationView.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import SwiftUI
import SwiftData

struct WorkoutCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var warmUpDuration: Double = 5.0
    @State private var runIntervalDuration: Double = 2.0
    @State private var walkIntervalDuration: Double = 1.0
    @State private var numberOfIntervals: Int = 5
    @State private var coolDownDuration: Double = 5.0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Name") {
                    TextField("Enter workout name", text: $name)
                }
                
                Section("Warm-up") {
                    Stepper("Duration: \(Int(warmUpDuration)) min", value: $warmUpDuration, in: 0...15, step: 1)
                }
                
                Section("Intervals") {
                    Stepper("Run Duration: \(formatMinutes(runIntervalDuration))", value: $runIntervalDuration, in: 0.5...10, step: 0.5)
                    
                    Stepper("Walk Duration: \(formatMinutes(walkIntervalDuration))", value: $walkIntervalDuration, in: 0.5...10, step: 0.5)
                    
                    HStack {
                        Text("Interval Time (Run + Walk)")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(formatIntervalTime())")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }
                    
                    Stepper("Number of Intervals: \(numberOfIntervals)", value: $numberOfIntervals, in: 1...20)
                }
                
                Section("Cool-down") {
                    Stepper("Duration: \(Int(coolDownDuration)) min", value: $coolDownDuration, in: 0...15, step: 1)
                }
                
                Section {
                    HStack {
                        Text("Total Duration")
                            .font(.headline)
                        Spacer()
                        Text(formatTotalDuration())
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .navigationTitle("Create Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWorkout()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func formatIntervalTime() -> String {
        let intervalTime = runIntervalDuration + walkIntervalDuration
        return formatMinutes(intervalTime)
    }
    
    private func formatMinutes(_ minutes: Double) -> String {
        if minutes.truncatingRemainder(dividingBy: 1) == 0 {
            // Whole number
            return "\(Int(minutes)) min"
        } else {
            // Has decimal (0.5)
            return String(format: "%.1f min", minutes)
        }
    }
    
    private func formatTotalDuration() -> String {
        // Total = Warm-up + (Number of Intervals × (Run + Walk)) + Cool-down
        let total = warmUpDuration + (Double(numberOfIntervals) * (runIntervalDuration + walkIntervalDuration)) + coolDownDuration
        let hours = Int(total) / 60
        let minutes = Int(total) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func saveWorkout() {
        // Round values to ensure they match the slider steps and avoid precision issues
        // Warm-up and cool-down: step 1, so round to nearest integer
        // Run and walk intervals: step 0.5, so round to nearest 0.5
        let workout = Workout(
            name: name.isEmpty ? "Untitled Workout" : name,
            warmUpDuration: round(warmUpDuration), // Round to nearest integer (step: 1)
            runIntervalDuration: round(runIntervalDuration * 2) / 2, // Round to nearest 0.5 (step: 0.5)
            walkIntervalDuration: round(walkIntervalDuration * 2) / 2, // Round to nearest 0.5 (step: 0.5)
            numberOfIntervals: numberOfIntervals,
            coolDownDuration: round(coolDownDuration) // Round to nearest integer (step: 1)
        )
        
        modelContext.insert(workout)
        dismiss()
    }
}

#Preview {
    WorkoutCreationView()
        .modelContainer(for: Workout.self, inMemory: true)
}

