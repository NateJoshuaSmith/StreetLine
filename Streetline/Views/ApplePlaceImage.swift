//
//  ApplePlaceImage.swift
//  Streetline
//
//  Default spot photo from Apple Look Around, with a map snapshot fallback.
//

import SwiftUI
import MapKit
import UIKit

enum ApplePlaceImageLoader {
    private static let cache = NSCache<NSString, UIImage>()
    
    static func image(for coordinate: CLLocationCoordinate2D) async -> UIImage? {
        let key = cacheKey(coordinate) as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        if let lookAround = await lookAroundImage(for: coordinate) {
            cache.setObject(lookAround, forKey: key)
            return lookAround
        }
        if let map = await mapSnapshot(for: coordinate) {
            cache.setObject(map, forKey: key)
            return map
        }
        return nil
    }
    
    static func jpegData(for coordinate: CLLocationCoordinate2D) async -> Data? {
        await image(for: coordinate)?.jpegData(compressionQuality: 0.78)
    }
    
    private static func cacheKey(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
    }
    
    private static func lookAroundImage(for coordinate: CLLocationCoordinate2D) async -> UIImage? {
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        guard let scene = try? await request.scene else { return nil }
        let options = MKLookAroundSnapshotter.Options()
        options.size = CGSize(width: 800, height: 500)
        let snapshotter = MKLookAroundSnapshotter(scene: scene, options: options)
        return try? await snapshotter.snapshot.image
    }
    
    private static func mapSnapshot(for coordinate: CLLocationCoordinate2D) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 180,
            longitudinalMeters: 180
        )
        options.size = CGSize(width: 800, height: 500)
        options.mapType = .satellite
        options.showsBuildings = true
        let snapshotter = MKMapSnapshotter(options: options)
        return try? await snapshotter.start().image
    }
}

struct ApplePlacePhotoView: View {
    let coordinate: CLLocationCoordinate2D
    var width: CGFloat? = nil
    var height: CGFloat = 200
    var cornerRadius: CGFloat = 16
    
    @State private var image: UIImage?
    @State private var didFinish = false
    
    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else if !didFinish {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(ProgressView())
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "map")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )
            }
        }
        .frame(width: width, height: height)
        .frame(maxWidth: width == nil ? .infinity : width)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: "\(coordinate.latitude),\(coordinate.longitude)") {
            image = await ApplePlaceImageLoader.image(for: coordinate)
            didFinish = true
        }
    }
}
