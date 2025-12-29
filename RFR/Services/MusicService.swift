//
//  MusicService.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import Foundation
import MusicKit
import Combine

enum MusicProvider: String, CaseIterable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case none = "None"
}

@MainActor
class MusicService: ObservableObject {
    static let shared = MusicService()
    
    @Published var currentProvider: MusicProvider = .none
    @Published var isAuthorized: Bool = false
    @Published var isPlaying: Bool = false
    
    private var appleMusicAuthorizationStatus: MusicAuthorization.Status = .notDetermined
    
    init() {
        // Don't request authorization on init - wait until user explicitly requests it
        // This prevents the app from crashing if Info.plist is not properly configured
    }
    
    // MARK: - Apple Music
    
    func checkAppleMusicAuthorization() {
        Task {
            // Check current status without requesting authorization
            // This will only show a prompt if status is .notDetermined
            let status = await MusicAuthorization.request()
            await MainActor.run {
                appleMusicAuthorizationStatus = status
                isAuthorized = status == .authorized
            }
        }
    }
    
    func requestAppleMusicAuthorization() async {
        let status = await MusicAuthorization.request()
        await MainActor.run {
            appleMusicAuthorizationStatus = status
            isAuthorized = status == .authorized
            if status == .authorized {
                currentProvider = .appleMusic
            }
        }
    }
    
    // MARK: - Spotify
    
    func setupSpotify() {
        // Note: Spotify iOS SDK requires additional setup
        // This is a placeholder for Spotify integration
        // In a real implementation, you would:
        // 1. Add Spotify iOS SDK via SPM or CocoaPods
        // 2. Configure Spotify app credentials
        // 3. Implement authentication flow
        // 4. Handle playback control
        
        currentProvider = .spotify
        isAuthorized = false // Will be true after successful authentication
    }
    
    // MARK: - Playback Control
    
    func play() {
        // Control playback based on current provider
        // For Apple Music, use MusicKit's playback controls
        // For Spotify, use Spotify SDK's playback controls
        isPlaying = true
    }
    
    func pause() {
        isPlaying = false
    }
    
    func skipNext() {
        // Implementation depends on provider
    }
    
    func skipPrevious() {
        // Implementation depends on provider
    }
}

