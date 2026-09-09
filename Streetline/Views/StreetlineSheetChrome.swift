//
//  StreetlineSheetChrome.swift
//  Streetline
//
//  Shared sheet header, cards, and sticker buttons.
//

import SwiftUI

struct StreetlineSheetHeader: View {
    let title: String
    var closeDisabled: Bool = false
    var onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Color.white)
                .overlay(Capsule().stroke(Color.black, lineWidth: 2))
                .frame(width: 52, height: 7)
                .padding(.top, 8)
                .accessibilityHidden(true)
            
            ZStack {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule().fill(Color.white)
                            Capsule().strokeBorder(Color.black, lineWidth: 2.5)
                        }
                    )
                    .padding(.horizontal, 88)
                
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white))
                            .overlay(Circle().stroke(Color.black, lineWidth: 2.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(closeDisabled)
                    .accessibilityLabel("Close")
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
    }
}

struct StreetlineCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(maxWidth: 400, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.black, lineWidth: 2.5)
            )
            .frame(maxWidth: .infinity)
    }
}

struct StreetlineStickerButton: View {
    let title: String
    let systemImage: String
    var fill: Color = Color(red: 0.08, green: 0.32, blue: 0.78)
    var enabled: Bool = true
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.heavy))
            Text(title)
                .font(.subheadline.weight(.heavy))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(enabled ? fill : Color.gray.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black, lineWidth: 2.5)
        )
        .opacity(enabled ? 1 : 0.75)
    }
}
