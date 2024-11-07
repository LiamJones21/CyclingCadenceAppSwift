//
//  ModelManagerView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//

// Views/ModelManagerView.swift

import SwiftUI
import UniformTypeIdentifiers

struct ModelManagerView: View {
    @ObservedObject var viewModel: ModelTrainingViewModel
    @State private var showFileImporter = false
    @State private var macModels: [ModelConfig] = []
    @State private var isConnectedToPhone = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Manage Models")
                .font(.largeTitle)
                .padding(.bottom, 10)

            List {
                Section(header: Text("Local Models")) {
                    ForEach(viewModel.models) { model in
                        HStack {
                            Text(model.name)
                            Spacer()
                            Button(action: {
                                removeModel(model)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .onDelete(perform: deleteModels)
                }

                if isConnectedToPhone && !viewModel.phoneModels.isEmpty {
                    Section(header: Text("Phone Models")) {
                        ForEach(viewModel.phoneModels) { model in
                            HStack {
                                Text(model.name)
                                Spacer()
                                Button("Import") {
                                    importModelFromPhone(modelName: model.name)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle()) // macOS compatible list style

            Spacer()

            HStack {
                Button(action: {
                    showFileImporter = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Model")
                    }
                }
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [UTType("com.apple.coreml.mlmodel")!], // Custom UTType
                    allowsMultipleSelection: false
                ) { result in
                    handleFileImport(result: result)
                }

                Spacer()
            }
            .padding()
        }
        .padding()
        .onAppear {
            isConnectedToPhone = !viewModel.connectedPeers.isEmpty
            if isConnectedToPhone {
                requestPhoneModels()
            }
        }
        .onReceive(viewModel.$connectedPeers) { peers in
            isConnectedToPhone = !peers.isEmpty
            if isConnectedToPhone {
                requestPhoneModels()
            }
        }
    }

    // MARK: - Model Management Functions

    func removeModel(_ model: ModelConfig) {
        if let index = viewModel.models.firstIndex(where: { $0.id == model.id }) {
            viewModel.models.remove(at: index)
            viewModel.saveLocalModels()
        }
    }

    func deleteModels(at offsets: IndexSet) {
        viewModel.models.remove(atOffsets: offsets)
        viewModel.saveLocalModels()
    }

    func requestPhoneModels() {
        if let peerID = viewModel.connectedPeers.first {
            let message: [String: Any] = ["type": "requestModelList"]
            viewModel.sendMessage(message: message, to: peerID)
        }
    }

    func importModelFromPhone(modelName: String) {
        if let peerID = viewModel.connectedPeers.first {
            let message: [String: Any] = ["type": "requestModel", "modelName": modelName]
            viewModel.sendMessage(message: message, to: peerID)
        }
    }

    func handleFileImport(result: Result<[URL], Error>) {
        do {
            let selectedFiles = try result.get()
            if let fileURL = selectedFiles.first {
                addModel(from: fileURL)
            }
        } catch {
            print("Error selecting file: \(error.localizedDescription)")
        }
    }

    func addModel(from url: URL) {
        do {
            let modelData = try Data(contentsOf: url)
            let destinationURL = getDocumentsDirectory().appendingPathComponent(url.lastPathComponent)
            try modelData.write(to: destinationURL)
            // Create a ModelConfig and add it to the models list
            let config = ModelConfig.Config(
                windowSize: 0,
                windowStep: 0,
                preprocessingType: "",
                filtering: "",
                scaler: "",
                usePCA: false,
                includeAcceleration: false,
                includeRotationRate: false
            )
            let modelConfig = ModelConfig(id: UUID(), name: url.lastPathComponent, config: config)
            viewModel.models.append(modelConfig)
            viewModel.saveLocalModels()
        } catch {
            print("Error importing model: \(error.localizedDescription)")
        }
    }

    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
