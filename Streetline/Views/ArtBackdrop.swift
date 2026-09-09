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
    var starBand: NightStarBand = .header
    
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
                if sky == .night {
                    NightStarField(band: starBand)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

enum NightStarBand: Equatable {
    /// Home / login logos (62pt pad + 120pt mark).
    case logo
    /// Nav title capsule, plus about one inch below it.
    case header
    /// Nav title, shifted up a little (Skate With, Favorites).
    case headerRaised
    /// Lobby: twice the header star band.
    case lobby
    
    func starRange(in height: CGFloat) -> ClosedRange<CGFloat> {
        switch self {
        case .logo:
            let bottom = min(182, height * 0.24)
            return 8...max(9, bottom)
        case .header:
            return Self.headerRange(in: height)
        case .headerRaised:
            return Self.headerRange(in: height, yOffset: -28)
        case .lobby:
            let header = Self.headerRange(in: height)
            let span = (header.upperBound - header.lowerBound) * 2
            let bottom = min(header.lowerBound + span, height * 0.5)
            return header.lowerBound...max(header.lowerBound + 1, bottom)
        }
    }
    
    private static func headerRange(in height: CGFloat, yOffset: CGFloat = 0) -> ClosedRange<CGFloat> {
        let headerTop: CGFloat = 48 + yOffset
        let headerHeight: CGFloat = 44
        let inch: CGFloat = 72
        let top = max(8, headerTop)
        let bottom = min(headerTop + headerHeight + inch, height * 0.32)
        return top...max(top + 1, bottom)
    }
}

private struct NightStarField: View {
    var band: NightStarBand
    
    var body: some View {
        GeometryReader { geo in
            let stars = Self.stars(in: geo.size, band: band)
            ZStack(alignment: .topLeading) {
                ForEach(Array(stars.enumerated()), id: \.offset) { _, star in
                    Circle()
                        .fill(Color.white.opacity(star.opacity))
                        .frame(width: star.size, height: star.size)
                        .blur(radius: star.size > 2.2 ? 0.4 : 0)
                        .position(x: star.x, y: star.y)
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private struct Star {
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
    }
    
    private static func stars(in size: CGSize, band: NightStarBand) -> [Star] {
        guard size.width > 0, size.height > 0 else { return [] }
        var rng = StarRNG(seed: 8_430)
        let yRange = band.starRange(in: size.height)
        let count: Int
        switch band {
        case .logo: count = 48
        case .header, .headerRaised: count = 56
        case .lobby: count = 90
        }
        return (0..<count).map { _ in
            Star(
                x: rng.nextCGFloat(in: 0...size.width),
                y: rng.nextCGFloat(in: yRange),
                size: rng.nextCGFloat(in: 1.0...2.6),
                opacity: rng.nextDouble(in: 0.4...0.95)
            )
        }
    }
}

/// Tiny deterministic RNG so stars stay put across redraws.
private struct StarRNG {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }
    
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    
    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() % 10_000) / 10_000.0
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }
    
    mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat(nextDouble(in: Double(range.lowerBound)...Double(range.upperBound)))
    }
}

enum TimeOfDaySky: Equatable {
    case morning, afternoon, evening, night
    
    static func current(at date: Date) -> TimeOfDaySky {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11: return .morning
        case 11..<17: return .afternoon
        case 17..<20: return .evening
        default: return .night
        }
    }
    
    /// Extra dim is reduced at night so screens that already darken stay readable.
    var dimScale: CGFloat {
        switch self {
        case .morning: return 0.85
        case .afternoon: return 1
        case .evening: return 0.7
        case .night: return 0.55
        }
    }
    
    var multiply: Color {
        switch self {
        case .morning: return Color(red: 1.0, green: 0.93, blue: 0.82)
        case .afternoon: return .white
        case .evening: return Color(red: 1.0, green: 0.78, blue: 0.62)
        case .night: return Color(red: 0.32, green: 0.38, blue: 0.62)
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
                Color(red: 0.02, green: 0.04, blue: 0.16).opacity(0.55),
                Color(red: 0.04, green: 0.06, blue: 0.18).opacity(0.35),
                Color.black.opacity(0.7)
            ]
        }
    }
}
