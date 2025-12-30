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
                .fullScreenCover(isPresented: $workoutPresentationManager.showLiveWorkout) {
                    if let workout = workoutPresentationManager.workoutToStart {
                        LiveWorkoutView(
                            workout: workout,
                            musicProvider: workoutPresentationManager.musicProvider
                        )
                    }
                }
        }
        .modelContainer(for: [Workout.self, WorkoutHistory.self])
    }
}
