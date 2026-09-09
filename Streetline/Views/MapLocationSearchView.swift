//
//  MapLocationSearchView.swift
//  Streetline
//

import SwiftUI
import MapKit

struct MapLocationSearchView: View {
    var onSelect: (TravelDestination) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var completer = LocationSearchCompleter()
    @FocusState private var searchFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                ArtBackdrop(imageName: "CityImage", dim: 0.22, starBand: .header)
                
                VStack(spacing: 14) {
                    StreetlineCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("GO SOMEWHERE")
                                .font(.caption.weight(.heavy))
                                .foregroundColor(.black)
                            
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .font(.body.weight(.bold))
                                    .foregroundColor(.black)
                                TextField("City, neighborhood, or place", text: $completer.query)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .foregroundColor(.black)
                                    .focused($searchFocused)
                                    .submitLabel(.search)
                                    .onSubmit {
                                        Task { await searchTypedQuery() }
                                    }
                                if completer.isResolving {
                                    ProgressView()
                                        .tint(.black)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.black, lineWidth: 2)
                            )
                            
                            if let error = completer.errorMessage {
                                Text(error)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    resultsBody
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                StreetlineSheetHeader(title: "Travel to") {
                    dismiss()
                }
            }
            .onAppear { searchFocused = true }
        }
    }
    
    @ViewBuilder
    private var resultsBody: some View {
        let query = completer.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if completer.results.isEmpty && query.isEmpty {
            StreetlineCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search a destination")
                        .font(.headline.weight(.heavy))
                        .foregroundColor(.black)
                    Text("Jump the map to another city to see spots, shops, and parks there.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black.opacity(0.72))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            Spacer()
        } else if completer.results.isEmpty {
            StreetlineCard {
                Text("No suggestions yet. Tap Search on the keyboard to look it up.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            Spacer()
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(Array(completer.results.enumerated()), id: \.offset) { _, completion in
                        Button {
                            Task { await select(completion) }
                        } label: {
                            StreetlineCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(completion.title)
                                        .font(.headline.weight(.heavy))
                                        .foregroundColor(.black)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.black.opacity(0.72))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(completer.isResolving)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }
    
    private func select(_ completion: MKLocalSearchCompletion) async {
        guard let destination = await completer.resolve(completion) else { return }
        await MainActor.run {
            onSelect(destination)
            dismiss()
        }
    }
    
    private func searchTypedQuery() async {
        guard let destination = await completer.resolveTypedQuery() else { return }
        await MainActor.run {
            onSelect(destination)
            dismiss()
        }
    }
}
