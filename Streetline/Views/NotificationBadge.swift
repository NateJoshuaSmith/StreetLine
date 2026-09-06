//
//  NotificationBadge.swift
//  Streetline
//
//  Red count badge for unread messages and friend requests.
//

import SwiftUI

struct NotificationBadge: View {
    let count: Int
    
    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, count > 9 ? 5 : 0)
                .frame(minWidth: 18, minHeight: 18)
                .background(Capsule().fill(Color.red))
                .overlay(Capsule().stroke(Color.white, lineWidth: 1.5))
        }
    }
}

extension View {
    func notificationBadge(_ count: Int, offset: CGSize = CGSize(width: 10, height: -8)) -> some View {
        overlay(alignment: .topTrailing) {
            NotificationBadge(count: count)
                .offset(x: offset.width, y: offset.height)
                .accessibilityHidden(count == 0)
        }
        .accessibilityLabel(count > 0 ? "Friends, \(count) unread" : "Friends")
    }
}
