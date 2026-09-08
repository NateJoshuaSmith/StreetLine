//
//  ArtBackdrop.swift
//  Streetline
//
//  Full-screen art background with a time-of-day grade.
//

import SwiftUI

struct ArtBackdrop: View {
    let imageName: String
    var dim: CGFloat = 0
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let sky = TimeOfDaySky.current(at: context.date)
            ZStack {
                Color.black
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .colorMultiply(sky.multiply)
                LinearGradient(
                    colors: sky.overlay,
                    startPoint: .top,
                    endPoint: .bottom
                )
                if dim > 0 {
                    Color.black.opacity(dim * sky.dimScale)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

enum TimeOfDaySky {
    case morning, afternoon, evening, night
    
    static func current(at date: Date) -> TimeOfDaySky {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11: return .morning
        case 11..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
    
    /// Extra dim is reduced at night so screens that already darken stay readable.
    var dimScale: CGFloat {
        switch self {
        case .morning: return 0.85
        case .afternoon: return 1
        case .evening: return 0.7
        case .night: return 0.4
        }
    }
    
    var multiply: Color {
        switch self {
        case .morning: return Color(red: 1.0, green: 0.93, blue: 0.82)
        case .afternoon: return .white
        case .evening: return Color(red: 1.0, green: 0.78, blue: 0.62)
        case .night: return Color(red: 0.48, green: 0.55, blue: 0.78)
        }
    }
    
    var overlay: [Color] {
        switch self {
        case .morning:
            return [
                Color.orange.opacity(0.18),
                Color.yellow.opacity(0.06),
                Color.black.opacity(0.38)
            ]
        case .afternoon:
            return [
                Color.black.opacity(0.12),
                Color.black.opacity(0.08),
                Color.black.opacity(0.45)
            ]
        case .evening:
            return [
                Color.orange.opacity(0.28),
                Color.purple.opacity(0.18),
                Color.black.opacity(0.52)
            ]
        case .night:
            return [
                Color(red: 0.05, green: 0.08, blue: 0.22).opacity(0.45),
                Color.black.opacity(0.28),
                Color.black.opacity(0.62)
            ]
        }
    }
}
