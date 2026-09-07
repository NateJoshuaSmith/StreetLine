//
//  ClipService.swift
//  Streetline
//
//  Upload and fetch trick clips for a skate spot.
//

import Foundation
import Combine
import AVFoundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

class ClipService: ObservableObject {
    static let maxUploadBytes = 40 * 1024 * 1024
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let authService = AuthService()
    private let userService = UserService()
    
    private func clipsRef(spotId: String) -> CollectionReference {
        db.collection("skateSpots").document(spotId).collection("clips")
    }
    
    func fetchClips(spotId: String, limit: Int = 20) async -> [SpotClip] {
        do {
            let snapshot = try await clipsRef(spotId: spotId)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: SpotClip.self) }
                .filter { !UserService.isUserBlocked($0.createdBy) }
        } catch {
            print("Error fetching clips: \(error)")
            return []
        }
    }
    
    func uploadClip(spotId: String, videoFileURL: URL, caption: String? = nil) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "ClipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in to post a clip"])
        }
        
        let scoped = videoFileURL.startAccessingSecurityScopedResource()
        defer {
            if scoped { videoFileURL.stopAccessingSecurityScopedResource() }
        }
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: videoFileURL.path)[.size] as? NSNumber)?.intValue ?? 0
        if fileSize > Self.maxUploadBytes {
            throw NSError(domain: "ClipService", code: 413, userInfo: [NSLocalizedDescriptionKey: "Clips must be under 40 MB"])
        }
        
        let username = await userService.getCurrentUsername()
        let clipId = UUID().uuidString
        let ext = videoFileURL.pathExtension.isEmpty ? "mp4" : videoFileURL.pathExtension.lowercased()
        let videoPath = "spotImages/\(uid)/\(clipId).\(ext)"
        let thumbPath = "spotImages/\(uid)/\(clipId).jpg"
        
        let videoRef = storage.reference().child(videoPath)
        let videoMeta = StorageMetadata()
        videoMeta.contentType = Self.videoContentType(for: ext)
        _ = try await videoRef.putFileAsync(from: videoFileURL, metadata: videoMeta)
        let videoURL = try await videoRef.downloadURL()
        
        var thumbnailURLString: String?
        if let thumbData = await Self.thumbnailJPEG(from: videoFileURL) {
            let thumbRef = storage.reference().child(thumbPath)
            let thumbMeta = StorageMetadata()
            thumbMeta.contentType = "image/jpeg"
            _ = try await thumbRef.putDataAsync(thumbData, metadata: thumbMeta)
            thumbnailURLString = try await thumbRef.downloadURL().absoluteString
        }
        
        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let clip = SpotClip(
            videoURL: videoURL.absoluteString,
            thumbnailURL: thumbnailURLString,
            createdBy: uid,
            createdByUsername: username,
            caption: (trimmedCaption?.isEmpty == false) ? trimmedCaption : nil
        )
        try clipsRef(spotId: spotId).addDocument(from: clip)
    }
    
    func deleteClip(spotId: String, clip: SpotClip) async throws {
        guard let uid = authService.currentUserId else {
            throw NSError(domain: "ClipService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        guard clip.createdBy == uid else {
            throw NSError(domain: "ClipService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You can only delete your own clips"])
        }
        guard let clipId = clip.id else { return }
        try await clipsRef(spotId: spotId).document(clipId).delete()
        try? await storage.reference(forURL: clip.videoURL).delete()
        if let thumb = clip.thumbnailURL {
            try? await storage.reference(forURL: thumb).delete()
        }
    }
    
    private static func videoContentType(for ext: String) -> String {
        switch ext {
        case "mov": return "video/quicktime"
        case "m4v": return "video/x-m4v"
        default: return "video/mp4"
        }
    }
    
    private static func thumbnailJPEG(from videoURL: URL) async -> Data? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        do {
            let image = try await generator.image(at: CMTime(seconds: 0.3, preferredTimescale: 600)).image
            let uiImage = UIImage(cgImage: image)
            return uiImage.jpegData(compressionQuality: 0.72)
        } catch {
            print("Clip thumbnail failed: \(error)")
            return nil
        }
    }
}
