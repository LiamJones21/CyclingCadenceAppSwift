//
//  DataView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// DataView.swift

import SwiftUI

struct DataView: View {
    @ObservedObject var viewModel: CyclingViewModel
    @State private var showExportOptions = false
    @State private var exportFileURL: FileExportItem?
    @State private var selectedSessionsToExport = [Session]()
    @State private var exportFormat: ExportFormat = .json

    enum ExportFormat: String, CaseIterable, Identifiable {
        case json = "JSON"
        case csv = "CSV"

        var id: String { self.rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.sessions) { session in
                    HStack {
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            HStack {
                                Text(session.name ?? session.dateFormatted)
                                    .font(.headline)
                                Spacer()
                                Text("\(session.data.count) data points")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                        Button(action: {
                            // Navigate to ModelTrainingView with selected session
                            let trainingViewModel = ModelTrainingViewModel(sessions: viewModel.sessions)
                            trainingViewModel.selectedSessions.insert(session.id)
                            let trainingView = ModelTrainingView(viewModel: trainingViewModel)
                            // Present the training view
                        }) {
                            Text("Train")
                        }
                    }
                }
                .onDelete { indexSet in
                    viewModel.deleteSession(at: indexSet)
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showExportOptions = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showExportOptions) {
                ExportOptionsView(
                    allSessions: viewModel.sessions,
                    selectedSessions: $selectedSessionsToExport,
                    exportFormat: $exportFormat,
                    exportAction: exportSelectedSessions,
                    cancelAction: { showExportOptions = false }
                )
            }
            .sheet(item: $exportFileURL) { fileExportItem in
                ShareSheet(activityItems: [fileExportItem.fileURL])
            }
        }
    }

    func exportSelectedSessions() {
        guard !selectedSessionsToExport.isEmpty else {
            print("No sessions selected for export")
            return
        }

        let fileURL: URL
        switch exportFormat {
        case .json:
            fileURL = exportSessionsAsJSON(sessions: selectedSessionsToExport)
        case .csv:
            fileURL = exportSessionsAsCSV(sessions: selectedSessionsToExport)
        }

        // Wrap the URL in FileExportItem to make it Identifiable
        exportFileURL = FileExportItem(fileURL: fileURL)
        showExportOptions = false
    }

    func exportSessionsAsJSON(sessions: [Session]) -> URL {
        let fileName = "ExportedSessions.json"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL)
            print("Sessions exported to \(fileURL)")
        } catch {
            print("Error exporting sessions: \(error)")
        }

        return fileURL
    }

    func exportSessionsAsCSV(sessions: [Session]) -> URL {
        let fileName = "ExportedSessions.csv"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)

        var csvText = "Session ID,Date,Data Point Count,Timestamp,Speed,Cadence,Gear,Terrain,IsStanding,Latitude,Longitude\n"

        for session in sessions {
            for dataPoint in session.data {
                let sessionId = session.id.uuidString
                let date = session.dateFormatted
                let timestamp = dataPoint.timestamp
                let speed = dataPoint.speed
                let cadence = dataPoint.cadence
                let gear = dataPoint.gear
                let terrain = dataPoint.terrain
                let isStanding = dataPoint.isStanding
                let latitude = dataPoint.location?.latitude ?? 0.0
                let longitude = dataPoint.location?.longitude ?? 0.0

                let line = "\(sessionId),\(date),\(session.data.count),\(timestamp),\(speed),\(cadence),\(gear),\(terrain),\(isStanding),\(latitude),\(longitude)\n"
                csvText.append(contentsOf: line)
            }
        }

        do {
            try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Sessions exported to \(fileURL)")
        } catch {
            print("Error exporting sessions: \(error)")
        }

        return fileURL
    }

    func getDocumentsDirectory() -> URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to access documents directory")
        }
        return documentsDirectory
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct FileExportItem: Identifiable {
    var id = UUID()
    var fileURL: URL
}
