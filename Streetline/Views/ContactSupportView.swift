//
//  ContactSupportView.swift
//  SpotFinder
//
//  Change supportEmail to your actual support address.
//

import SwiftUI

struct ContactSupportView: View {
    // Change this to your support email address
    private let supportEmail = "support@yourapp.com"
    
    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var didCopyEmail = false
    @Environment(\.dismiss) private var dismiss
    
    private let stickerBlue = Color(red: 0.18, green: 0.78, blue: 1.0)
    
    var body: some View {
        ZStack {
            cityBackdrop
            
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack {
                        SpotFinderLogoBadge(showsOutline: true)
                            .padding(.top, 36)
                        
                        Spacer(minLength: 16)
                        contactCard
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.95)))
                    .overlay(
                        Circle().stroke(Color.black, lineWidth: 2.5)
                    )
                    .padding(2)
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            .padding(.top, 22)
            .accessibilityLabel("Close")
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
    }
    
    private var cityBackdrop: some View {
        ZStack {
            Color.black
            Image("CityImage")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
            LinearGradient(
                colors: [
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
    
    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONTACT US")
                .font(.title3.weight(.heavy))
                .tracking(1)
                .frame(maxWidth: .infinity)
            
            compactField(title: "Subject") {
                TextField("What's this about?", text: $subject)
                    .textFieldStyle(.plain)
            }
            
            compactField(title: "Message") {
                TextField("Describe your issue...", text: $message, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(5...10)
            }
            
            Text("Your message will open in Mail. App version is included to help us assist you.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: openMail) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.subheadline.weight(.heavy))
                    Text("OPEN IN MAIL")
                        .font(.subheadline.weight(.heavy))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(stickerBlue)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black, lineWidth: 2.5)
                )
                .shadow(color: stickerBlue.opacity(0.7), radius: 10, y: 3)
            }
            .disabled(subject.isEmpty || message.isEmpty)
            .opacity(subject.isEmpty || message.isEmpty ? 0.6 : 1.0)
            .padding(.top, 4)
            
            Button(action: copyEmail) {
                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Image(systemName: didCopyEmail ? "checkmark" : "doc.on.doc.fill")
                    Text(didCopyEmail ? "Copied" : "Copy Support Email")
                    Spacer(minLength: 0)
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black, lineWidth: 2.5)
        )
    }
    
    private func compactField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.heavy))
            content()
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
    
    private func buildEmailBody() -> String {
        var lines: [String] = []
        lines.append("---")
        lines.append("SpotFinder \(appVersion)")
        lines.append("---")
        lines.append("")
        lines.append(message)
        return lines.joined(separator: "\n")
    }
    
    private func openMail() {
        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let bodyEncoded = buildEmailBody().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailto = "mailto:\(supportEmail)?subject=\(subjectEncoded)&body=\(bodyEncoded)"
        
        if let url = URL(string: mailto) {
            UIApplication.shared.open(url)
        }
    }
    
    private func copyEmail() {
        UIPasteboard.general.string = supportEmail
        didCopyEmail = true
    }
}

/// Sheet chrome matching Sign Up: handle sits on the stack, not under the nav bar.
extension ContactSupportView {
    static var sheet: some View {
        NavigationStack {
            ContactSupportView()
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.95))
                .overlay(
                    Capsule()
                        .stroke(Color.black, lineWidth: 2)
                )
                .frame(width: 52, height: 7)
                .padding(.top, 8)
                .accessibilityHidden(true)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

#Preview {
    ContactSupportView.sheet
}
