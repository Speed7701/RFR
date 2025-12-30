//
//  IntervalType.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import Foundation

enum IntervalType: String, CaseIterable {
    case warmUp = "Warm-up"
    case running = "Running"
    case walking = "Walking"
    case coolDown = "Cool-down"
    
    var displayName: String {
        rawValue
    }
    
    var emoji: String {
        switch self {
        case .warmUp: return "🔥"
        case .running: return "🏃"
        case .walking: return "🚶"
        case .coolDown: return "🧘"
        }
    }
    
    var icon: String {
        switch self {
        case .warmUp: return "flame.fill"
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .coolDown: return "wind"
        }
    }
}

