//
//  EmptyStateCard.swift
//  Streetline
//
//  High-contrast empty state for dark photo backgrounds.
//

import SwiftUI

struct EmptyStateCard: View {
    let title: String
    let systemImage: String
    let message: String
    
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(Color(red: 0.18, green: 0.78, blue: 1.0))
                )
                .overlay(
                    Circle().stroke(Color.black, lineWidth: 2.5)
                )
            
            Text(title)
                .font(.title3.weight(.heavy))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.black.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 22)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black, lineWidth: 2.5)
        )
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
