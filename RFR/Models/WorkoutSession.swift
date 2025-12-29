//
//  WorkoutSession.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import Foundation

struct WorkoutSession {
    let workout: Workout
    var state: WorkoutState
    var startTime: Date?
    var endTime: Date?
    
    init(workout: Workout) {
        self.workout = workout
        self.state = WorkoutState()
        self.state.remainingIntervals = workout.numberOfIntervals
    }
}

