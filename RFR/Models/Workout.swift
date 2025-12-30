//
//  Workout.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import Foundation
import SwiftData

@Model
final class Workout {
    var id: UUID
    var name: String
    var warmUpDuration: Double // minutes
    var runIntervalDuration: Double // minutes
    var walkIntervalDuration: Double // minutes
    var numberOfIntervals: Int
    var coolDownDuration: Double // minutes
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        warmUpDuration: Double,
        runIntervalDuration: Double,
        walkIntervalDuration: Double,
        numberOfIntervals: Int,
        coolDownDuration: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.warmUpDuration = warmUpDuration
        self.runIntervalDuration = runIntervalDuration
        self.walkIntervalDuration = walkIntervalDuration
        self.numberOfIntervals = numberOfIntervals
        self.coolDownDuration = coolDownDuration
        self.createdAt = createdAt
    }
    
    /// Calculates total workout duration in minutes
    /// Formula: Warm-up + (Number of Intervals × (Run Duration + Walk Duration)) + Cool-down
    /// Each interval includes both run and walk phases
    var totalDuration: Double {
        warmUpDuration + (Double(numberOfIntervals) * (runIntervalDuration + walkIntervalDuration)) + coolDownDuration
    }
}

