//
//  WorkoutStartView.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//

import SwiftUI

struct WorkoutStartView: View {
    let workout: Workout
    let onStart: (MusicProvider) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var musicService = MusicService.shared
    @State private var selectedProvider: MusicProvider = .none
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Ready to Start?")
                    .font(.title)
                    .bold()
                
                // Music Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Music Provider")
                        .font(.headline)
                    
                    Picker("Music Provider", selection: $selectedProvider) {
                        ForEach(MusicProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if selectedProvider == .appleMusic {
                        if !musicService.isAuthorized {
                            Button("Authorize Apple Music") {
                                Task {
                                    await musicService.requestAppleMusicAuthorization()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    } else if selectedProvider == .spotify {
                        Button("Connect Spotify") {
                            musicService.setupSpotify()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Start Button
                Button(action: {
                    musicService.currentProvider = selectedProvider
                    onStart(selectedProvider)
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Workout")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("Start Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    WorkoutStartView(
        workout: Workout(
            name: "Test Workout",
            warmUpDuration: 5,
            runIntervalDuration: 2,
            walkIntervalDuration: 1,
            numberOfIntervals: 5,
            coolDownDuration: 5
        ),
        onStart: { _ in }
    )
}

