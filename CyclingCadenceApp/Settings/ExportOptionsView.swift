//
//  ExportOptionsView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 26/10/2024.
// ExportOptionsView.swift

import SwiftUI

struct ExportOptionsView: View {
    let allSessions: [Session]
    @Binding var selectedSessions: [Session]
    @Binding var exportFormat: DataView.ExportFormat
    let exportAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Export Format")) {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(DataView.ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Selected Sessions")) {
                    List {
                        ForEach(selectedSessions) { session in
                            HStack {
                                Text(session.name ?? session.dateFormatted)
                                    .font(.headline)
                                Spacer()
                                Text("\(session.data.count) data points")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .onDelete { indices in
                            selectedSessions.remove(atOffsets: indices)
                        }
                    }
                    HStack {
                        Spacer()
                        Text("Total Sessions: \(selectedSessions.count)")
                        Spacer()
                    }
                }

                Button(action: {
                    showAddSessionsView = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Sessions")
                    }
                }
            }
            .navigationTitle("Export Options")
            .navigationBarItems(leading: Button("Cancel") {
                cancelAction()
            }, trailing: Button("Export") {
                exportAction()
            })
            .sheet(isPresented: $showAddSessionsView) {
                AddSessionsView(
                    allSessions: allSessions,
                    selectedSessions: $selectedSessions
                )
            }
        }
    }

    @State private var showAddSessionsView = false
}

struct AddSessionsView: View {
    let allSessions: [Session]
    @Binding var selectedSessions: [Session]
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                ForEach(allSessions) { session in
                    Button(action: {
                        if !selectedSessions.contains(where: { $0.id == session.id }) {
                            selectedSessions.append(session)
                        }
                    }) {
                        HStack {
                            Text(session.name ?? session.dateFormatted)
                                .font(.headline)
                            Spacer()
                            Text("\(session.data.count) data points")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Add Sessions")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
