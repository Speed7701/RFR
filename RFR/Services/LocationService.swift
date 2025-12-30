//
//  LocationService.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var locations: [CLLocation] = []
    @Published var totalDistance: Double = 0 // meters
    @Published var currentPace: Double? // seconds per meter
    
    private var lastValidLocation: CLLocation?
    private var paceHistory: [Double] = []
    private let paceHistorySize = 10
    
    override init() {
        super.init()
        print("=== LocationService.init called ===")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // meters
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
        
        // DO NOT set allowsBackgroundLocationUpdates in init()
        // This must only be set AFTER:
        // 1. User has authorized "Always" location access
        // 2. App has background location capability enabled
        // We'll set it in startTracking() after checking authorization
        print("LocationService initialized, authorization status: \(authorizationStatus.rawValue)")
    }
    
    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startTracking() {
        print("=== LocationService.startTracking called ===")

        // Avoid synchronous status APIs on the main thread.
        // If services are globally disabled, just log and return; the user can enable them in Settings.
        if !CLLocationManager.locationServicesEnabled() {
            print("Location services are disabled at the system level.")
            return
        }

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            // Already authorized — begin updates.
            beginLocationUpdatesIfAuthorized()
        case .notDetermined:
            // Request authorization; we'll start updates in the delegate callback.
            print("Location not determined, requesting authorization…")
            requestAuthorization()
        default:
            // For denied/restricted, log and do nothing. The app can surface UI elsewhere.
            print("Location not authorized (status: \(authorizationStatus.rawValue)).")
        }
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        reset()
    }
    
    func reset() {
        locations = []
        totalDistance = 0
        currentPace = nil
        lastValidLocation = nil
        paceHistory = []
        currentLocation = nil
    }
    
    private func beginLocationUpdatesIfAuthorized() {
        // Ensure we only touch background updates flag after authorization
        if authorizationStatus == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
            print("✓ Background location updates enabled")
        } else {
            locationManager.allowsBackgroundLocationUpdates = false
            print("Using 'When In Use' location - background updates disabled")
        }

        print("Starting location updates…")
        locationManager.startUpdatingLocation()
        print("✓ Location tracking started")
    }
    
    private func updateDistance(with newLocation: CLLocation) {
        guard let lastLocation = lastValidLocation else {
            lastValidLocation = newLocation
            return
        }
        
        // Filter inaccurate readings
        guard newLocation.horizontalAccuracy >= 0 && newLocation.horizontalAccuracy < 50 else {
            return
        }
        
        let distance = newLocation.distance(from: lastLocation)
        totalDistance += distance
        locations.append(newLocation)
        lastValidLocation = newLocation
        
        // Calculate pace (seconds per meter)
        let timeDelta = newLocation.timestamp.timeIntervalSince(lastLocation.timestamp)
        if timeDelta > 0 && distance > 0 {
            let pace = timeDelta / distance
            paceHistory.append(pace)
            if paceHistory.count > paceHistorySize {
                paceHistory.removeFirst()
            }
            
            // Use rolling average for smoother pace readings
            currentPace = paceHistory.reduce(0, +) / Double(paceHistory.count)
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            currentLocation = location
            updateDistance(with: location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("Location error: \(error.localizedDescription)")
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            // Start updates if we became authorized
            if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                beginLocationUpdatesIfAuthorized()
            }
        }
    }
}

