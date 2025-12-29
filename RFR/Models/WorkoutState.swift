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
    var totalElapsedTime: TimeInterval = 0
    var totalDistance: Double = 0 // meters
    var currentPace: Double? // seconds per meter (nil if not enough data)
    var intervalDistance: Double = 0 // meters covered in current interval
    var intervalStartTime: Date?
    var remainingIntervals: Int = 0
    
    // Location tracking
    var locations: [CLLocation] = []
    var lastLocation: CLLocation?
    
    mutating func reset() {
        isActive = false
        isPaused = false
        currentIntervalType = .warmUp
        currentIntervalIndex = 0
        elapsedTimeInCurrentInterval = 0
        totalElapsedTime = 0
        totalDistance = 0
        currentPace = nil
        intervalDistance = 0
        intervalStartTime = nil
        remainingIntervals = 0
        locations = []
        lastLocation = nil
    }
}

import CoreLocation

