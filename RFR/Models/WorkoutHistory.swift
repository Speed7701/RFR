//
//  WorkoutHistory.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import Foundation
import SwiftData

@Model
final class WorkoutHistory {
    var id: UUID
    var workoutName: String
    var startTime: Date
    var endTime: Date
    var totalDistance: Double // meters
    var averagePace: Double? // seconds per meter
    var totalDuration: TimeInterval // seconds
    
    init(
        id: UUID = UUID(),
        workoutName: String,
        startTime: Date,
        endTime: Date,
        totalDistance: Double,
        averagePace: Double?,
        totalDuration: TimeInterval
    ) {
        self.id = id
        self.workoutName = workoutName
        self.startTime = startTime
        self.endTime = endTime
        self.totalDistance = totalDistance
        self.averagePace = averagePace
        self.totalDuration = totalDuration
    }
}



