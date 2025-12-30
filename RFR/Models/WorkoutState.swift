//
//  WorkoutState.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import Foundation

struct WorkoutState {
    var isActive: Bool = false
    var isPaused: Bool = false
    var currentIntervalType: IntervalType = .warmUp
    var currentIntervalIndex: Int = 0
    var elapsedTimeInCurrentInterval: TimeInterval = 0
    var intervalRemainingTime: TimeInterval = 0 // Remaining time in current interval (countdown)
    var totalElapsedTime: TimeInterval = 0
    var totalDistance: Double = 0 // meters
    var currentPace: Double? // seconds per meter (nil if not enough data)
    var intervalDistance: Double = 0 // meters covered in current interval
    var intervalStartTime: Date?
    var intervalStartTime: Date?
    var remainingIntervals: Int = 0 // Deprecated - use remainingRunIntervals and remainingWalkIntervals
    var remainingRunIntervals: Int = 0
    var remainingWalkIntervals: Int = 0
    
    // Location tracking
    
    mutating func reset() {
        isActive = false
        isPaused = false
        currentIntervalType = .warmUp
        currentIntervalIndex = 0
        elapsedTimeInCurrentInterval = 0
        intervalRemainingTime = 0
        totalElapsedTime = 0
        totalDistance = 0
        currentPace = nil
        intervalDistance = 0
        intervalStartTime = nil
        remainingIntervals = 0
        remainingRunIntervals = 0
        remainingWalkIntervals = 0
        locations = []
        lastLocation = nil
    }
}

import CoreLocation

