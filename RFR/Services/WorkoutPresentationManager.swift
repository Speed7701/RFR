//
//  WorkoutPresentationManager.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import Foundation
import SwiftUI

@MainActor
class WorkoutPresentationManager: ObservableObject {
    static let shared = WorkoutPresentationManager()
    
    @Published var workoutToStart: Workout?
    @Published var musicProvider: MusicProvider = .none
    @Published var showLiveWorkout = false
    
    func presentWorkout(_ workout: Workout, musicProvider: MusicProvider) {
        print("WorkoutPresentationManager: presentWorkout called - \(workout.name)")
        self.workoutToStart = workout
        self.musicProvider = musicProvider
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.showLiveWorkout = true
            print("WorkoutPresentationManager: showLiveWorkout set to true")
        }
    }
    
    func dismissWorkout() {
        showLiveWorkout = false
        workoutToStart = nil
        musicProvider = .none
    }
}

