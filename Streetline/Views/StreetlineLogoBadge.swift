//
//  StreetlineLogoBadge.swift
//  Streetline
//

import SwiftUI

struct StreetlineLogoBadge: View {
    var size: CGFloat = 148
    var showsOutline: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.22), radius: max(8, size * 0.1), y: 6)
            
            if showsOutline {
                Circle()
                    .stroke(Color.black, lineWidth: 2.5)
            }
            
            Image("UpdatedLogo")
                .resizable()
                .scaledToFit()
                .scaleEffect(1.28)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Streetline")
    }
}
