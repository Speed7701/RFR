//
//  VoiceService.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import Foundation
import AVFoundation
import Combine

@MainActor
class VoiceService: NSObject, ObservableObject {
    static let shared = VoiceService()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var audioSession: AVAudioSession { AVAudioSession.sharedInstance() }
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetoothA2DP])
            try audioSession.setActive(true)
            print("Audio session configured successfully")
        } catch {
            print("ERROR: Failed to setup audio session: \(error.localizedDescription)")
            // Don't crash - audio will still work but may not duck other audio
        }
    }
    
    func speak(_ text: String, completion: (() -> Void)? = nil) {
        guard !text.isEmpty else {
            print("WARNING: Attempted to speak empty text")
            completion?()
            return
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.delegate = self
        
        if let completion = completion {
            pendingCompletions[utterance] = completion
        }
        
        print("Speaking: \(text)")
        synthesizer.speak(utterance)
    }
    
    private var pendingCompletions: [AVSpeechUtterance: () -> Void] = [:]
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        pendingCompletions.removeAll()
    }
    
    func announceWarmUp(duration: Double) {
        let minutes = Int(duration)
        let text = "Starting warm-up for \(minutes) minute\(minutes == 1 ? "" : "s")"
        speak(text)
    }
    
    func announceCoolDown(duration: Double) {
        let minutes = Int(duration)
        let text = "Starting cool-down for \(minutes) minute\(minutes == 1 ? "" : "s")"
        speak(text)
    }
    
    func announceIntervalStart(type: IntervalType) {
        let text: String
        switch type {
        case .running:
            text = "Begin running interval"
        case .walking:
            text = "Begin walking interval"
        default:
            return
        }
        speak(text)
    }
    
    func announceIntervalComplete(type: IntervalType, distance: Double, pace: Double?) {
        guard type == .running else { return }
        
        let distanceMiles = distance / 1609.34
        let distanceKm = distance / 1000.0
        
        var text = "Running interval complete. "
        
        // Format distance
        if distanceMiles >= 0.1 {
            text += String(format: "Distance: %.2f miles. ", distanceMiles)
        } else {
            text += String(format: "Distance: %.2f kilometers. ", distanceKm)
        }
        
        // Format pace
        if let pace = pace {
            let pacePerMeter = pace // seconds per meter
            let pacePerMile = pacePerMeter * 1609.34 // seconds per mile
            let minutesPerMile = pacePerMile / 60.0
            
            let minutes = Int(minutesPerMile)
            let seconds = Int((minutesPerMile - Double(minutes)) * 60)
            text += String(format: "Pace: %d:%02d per mile. ", minutes, seconds)
        }
        
        speak(text)
    }
    
    func countdown(seconds: Int, completion: @escaping () -> Void) {
        guard seconds > 0 else {
            completion()
            return
        }
        
        // Just announce "X seconds remaining" once, don't count down
        let announcement: String
        if seconds == 10 {
            announcement = "10 seconds remaining"
        } else {
            announcement = "\(seconds) seconds remaining"
        }
        
        speak(announcement) {
            completion()
        }
    }
    
    func announceWorkoutComplete(totalDistance: Double, totalTime: TimeInterval) {
        let distanceMiles = totalDistance / 1609.34
        let hours = Int(totalTime) / 3600
        let minutes = (Int(totalTime) % 3600) / 60
        
        var text = "Workout complete. Great job! "
        text += String(format: "Total distance: %.2f miles. ", distanceMiles)
        text += String(format: "Total time: %d hour\(hours == 1 ? "" : "s") and %d minute\(minutes == 1 ? "" : "s").", hours, minutes)
        
        speak(text)
    }
}

extension VoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Use ObjectIdentifier to avoid capturing non-Sendable AVSpeechUtterance
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            // Find completion by matching object identifier
            if let (key, completion) = self.pendingCompletions.first(where: { ObjectIdentifier($0.key) == utteranceID }) {
                self.pendingCompletions.removeValue(forKey: key)
                completion()
            }
        }
    }
}

