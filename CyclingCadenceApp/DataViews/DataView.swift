//
//  DataView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// DataView.swift

import SwiftUI

struct DataView: View {
    @ObservedObject public var viewModel: CyclingViewModel
    @StateObject public var modelTrainingViewModel: ModelTrainingViewModel
    @State private var editMode = EditMode.inactive
    @State private var selectedSessions = Set<UUID>()
    @State private var navigateToTrainingView = false
    @State private var showRenameAlert = false
    @State private var newSessionName = ""
    @State private var exportFileURL: FileExportItem?
    @State private var showExportOptions = false
    @State private var exportFormat: ExportFormat = .json
    init(viewModel: CyclingViewModel) {
            self.viewModel = viewModel
            _modelTrainingViewModel = StateObject(wrappedValue: ModelTrainingViewModel(cyclingViewModel: viewModel))
        }

    var body: some View {
        NavigationView {
            List(selection: $selectedSessions) {
                ForEach(viewModel.sessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        sessionRow(for: session)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteSession(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            newSessionName = session.name ?? ""
                            selectedSessions = [session.id] // Set selected session for renaming
                            showRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(editMode == .active ? "Done" : "Select") {
                        editMode = editMode == .active ? .inactive : .active
                    }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    if editMode == .active {
                        Button(action: deleteSelectedSessions) {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .disabled(selectedSessions.isEmpty)

                        Spacer()

                        Button(action: exportSelectedSessions) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export")
                        }
                        .disabled(selectedSessions.isEmpty)

                        Spacer()

                        Button(action: navigateToModelTrainingView) {
                            Image(systemName: "waveform.path.ecg")
                            Text("Train")
                        }
                        .disabled(selectedSessions.isEmpty)

                        Spacer()

                        if selectedSessions.count == 1 {
                            Button(action: {
                                showRenameAlert = true
                            }) {
                                Image(systemName: "pencil")
                                Text("Rename")
                            }
                        } else {
                            Button(action: {}) {
                                Image(systemName: "pencil")
                                Text("Rename")
                            }
                            .disabled(true)
                        }
                    }
                }
                
            }
            .environment(\.editMode, $editMode)
            .background(
                NavigationLink(
                    destination: ModelTrainingView(
                        cyclingViewModel: viewModel,
                        viewModel: modelTrainingViewModel,
                        selectedSessionIDs: Array(selectedSessions)
                    ),
                    isActive: $navigateToTrainingView
                ) {
                    EmptyView()
                }
            )
            .textFieldAlert(isPresented: $showRenameAlert, alert: TextFieldAlert(
                title: "Rename Session",
                message: "Enter a new name for the session",
                action: { newName in
                    if let newName = newName, !newName.isEmpty {
                        renameSelectedSession(newName: newName)
                    }
                }
            ))
            .sheet(item: $exportFileURL) { fileExportItem in
                ShareSheet(activityItems: [fileExportItem.fileURL])
            }
        }
    }

    func navigateToModelTrainingView() {
        navigateToTrainingView = true
    }

    func deleteSelectedSessions() {
        for sessionId in selectedSessions {
            if let index = viewModel.sessions.firstIndex(where: { $0.id == sessionId }) {
                viewModel.sessions.remove(at: index)
            }
        }
        selectedSessions.removeAll()
        viewModel.saveSessionsToFile() // Save the updated sessions
    }
    func deleteSession(_ session: Session) {
        if let index = viewModel.sessions.firstIndex(where: { $0.id == session.id }) {
            viewModel.sessions.remove(at: index)
            viewModel.saveSessionsToFile()
        }
    }

    func exportSelectedSessions() {
        guard !selectedSessions.isEmpty else {
                print("No sessions selected for export")
                return
            }

        // Generate JSON file
        let fileURL = exportSessionsAsJSON(sessions: selectedSessions.map { id in viewModel.sessions.first { $0.id == id }! })

        // Wrap the URL in FileExportItem to make it Identifiable for the share sheet
        exportFileURL = FileExportItem(fileURL: fileURL)
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

    func renameSelectedSession(newName: String) {
        guard let sessionId = selectedSessions.first else { return }
        if let index = viewModel.sessions.firstIndex(where: { $0.id == sessionId }) {
            viewModel.sessions[index].name = newName
            viewModel.saveSessionsToFile()
            viewModel.loadSessionsFromFile()
        }
    }
    
    func sessionRow(for session: Session) -> some View {
        HStack {
            Text(session.name ?? session.dateFormatted)
                .font(.headline)
            Spacer()
            Text("\(session.data.count) data points")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .contentShape(Rectangle())
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

extension View {
    func textFieldAlert(isPresented: Binding<Bool>, alert: TextFieldAlert) -> some View {
        TextFieldAlertWrapper(isPresented: isPresented, alert: alert, presenting: { self })
    }
}

struct TextFieldAlertWrapper<Presenting>: View where Presenting: View {
    @Binding var isPresented: Bool
    let alert: TextFieldAlert
    let presenting: () -> Presenting

    var body: some View {
        ZStack {
            if isPresented {
                presenting()
                    .background(
                        TextFieldAlertController(isPresented: $isPresented, alert: alert)
                            .frame(width: 0, height: 0)
                    )
            } else {
                presenting()
            }
        }
    }
}

struct TextFieldAlertController: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let alert: TextFieldAlert

    func makeUIViewController(context: UIViewControllerRepresentableContext<TextFieldAlertController>) -> UIViewController {
        UIViewController() // Empty view controller host
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard context.coordinator.alert == nil, isPresented else { return }

        let alertController = UIAlertController(title: alert.title, message: alert.message, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "New session name"
        }
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            isPresented = false
            alert.action(nil)
        })
        alertController.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            isPresented = false
            alert.action(alertController.textFields?.first?.text)
        })

        context.coordinator.alert = alertController
        DispatchQueue.main.async {
            uiViewController.present(alertController, animated: true, completion: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var alert: UIAlertController?
        var parent: TextFieldAlertController

        init(_ parent: TextFieldAlertController) {
            self.parent = parent
        }
    }
}
