//
//  IconGenerator.swift
//  RFR
//
//  Created by Anthony Swan on 25/11/2025.
//
//  This file contains a SwiftUI view that can be used to generate app icons
//  To create the actual icon:
//  1. Run this view in a preview or simulator
//  2. Take a screenshot at 1024x1024 resolution
//  3. Export and add to AppIcon.appiconset
//

import SwiftUI

struct AppIconView: View {
    var size: CGFloat = 1024
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.4, blue: 0.9),
                    Color(red: 0.5, green: 0.3, blue: 0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // RFR Text
            Text("RFR")
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
    }
}

#Preview {
    AppIconView(size: 200)
        .padding()
}



