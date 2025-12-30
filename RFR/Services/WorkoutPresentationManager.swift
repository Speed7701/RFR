//
//  WorkoutPresentationManager.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class WorkoutPresentationManager: ObservableObject {
    static let shared = WorkoutPresentationManager()
    
    @Published var workoutToStart: Workout?
    @Published var musicProvider: MusicProvider = .none
    @Published var showLiveWorkout = false
    
    /// Internal initializer to allow usage in previews and tests
    init() {}

    /// Convenience instance for SwiftUI previews
    static let preview = WorkoutPresentationManager()
    
    func presentWorkout(_ workout: Workout, musicProvider: MusicProvider) {
        print("🔵 [WorkoutPresentationManager] presentWorkout called - \(workout.name)")
        print("🔵 [WorkoutPresentationManager] Music provider: \(musicProvider)")
        self.workoutToStart = workout
        self.musicProvider = musicProvider
        // Use a small delay to ensure any sheets are dismissed first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("🔵 [WorkoutPresentationManager] Setting showLiveWorkout = true")
            self.showLiveWorkout = true
        }
    }
    
    func dismissWorkout() {
        print("🔵 [WorkoutPresentationManager] dismissWorkout called")
        showLiveWorkout = false
        workoutToStart = nil
        musicProvider = .none
    }
}

