//
//  SessionSelectorView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/7/24.
//


// Views/SessionSelectorView.swift

import SwiftUI

struct SessionSelectorView: View {
    let sessions: [Session]
    @Binding var selectedSessions: [Session]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List(sessions, id: \.id) { session in
                HStack {
                    Text(session.name ?? session.dateFormatted)
                    Spacer()
                    if selectedSessions.contains(where: { $0.id == session.id }) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleSelection(for: session)
                }
            }
            .navigationTitle("Select Sessions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    func toggleSelection(for session: Session) {
        if let index = selectedSessions.firstIndex(where: { $0.id == session.id }) {
            selectedSessions.remove(at: index)
        } else {
            selectedSessions.append(session)
        }
    }
}
