//
//  ReportContentView.swift
//  Streetline
//
//  Shared report sheet for any user-generated content or account.
//

import SwiftUI

struct ReportContentView: View {
    let title: String
    let prompt: String
    let type: ReportTargetType
    let targetId: String
    let targetPreview: String?
    let reportedUserId: String
    var spotId: String? = nil
    var spotName: String? = nil
    var onDismiss: () -> Void
    
    @StateObject private var reportService = ReportService()
    @State private var selectedReasonId: String = ReportService.reportReasons[0].id
    @State private var commentText: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Reason", selection: $selectedReasonId) {
                        ForEach(ReportService.reportReasons, id: \.id) { reason in
                            Text(reason.label).tag(reason.id)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text(prompt)
                }
                Section {
                    TextField("Additional details (optional)", text: $commentText, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Details")
                }
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                    .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task { await submit() }
                    }
                    .disabled(isSubmitting)
                }
            }
            .alert("Report submitted", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                    onDismiss()
                }
            } message: {
                Text("Thank you. We'll review this report.")
            }
        }
    }
    
    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await reportService.submitContentReport(
                type: type,
                targetId: targetId,
                targetPreview: targetPreview,
                reportedUserId: reportedUserId,
                reason: selectedReasonId,
                comment: commentText.isEmpty ? nil : commentText,
                spotId: spotId,
                spotName: spotName
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
