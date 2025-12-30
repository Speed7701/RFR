//
//  RFRApp.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import SwiftUI
import SwiftData

@main
struct RFRApp: App {
    @StateObject private var workoutPresentationManager = WorkoutPresentationManager.shared
    
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(workoutPresentationManager)
                .fullScreenCover(item: $workoutPresentationManager.workoutToStart) { workout in
                    LiveWorkoutView(
                        workout: workout,
                        musicProvider: workoutPresentationManager.musicProvider
                    )
                    .onAppear {
                        print("🔵 [RFRApp] Presenting LiveWorkoutView for \(workout.name)")
                    }
                }
        }
        .modelContainer(for: [Workout.self, WorkoutHistory.self])
    }
}

