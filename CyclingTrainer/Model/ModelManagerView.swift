//
//  ModelManagerView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


// Views/ModelManagerView.swift

import SwiftUI

struct ModelManagerView: View {
    @ObservedObject var viewModel: ModelTrainingViewModel

    var body: some View {
        VStack(alignment: .leading) {
            Text("Models")
                .font(.largeTitle)
                .padding(.bottom, 10)

            List {
                Section(header: Text("Local Models")) {
                    ForEach(viewModel.models) { model in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(model.name)
                                    .font(.headline)
                                Text("RMSE: \(String(format: "%.2f", viewModel.bestAccuracy ?? 0.0))")
                                    .font(.subheadline)
                            }
                            Spacer()
                            Button(action: {
                                viewModel.sendModel(model: model)
                            }) {
                                Text("Send to Phone")
                                    .padding(5)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(5)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }

                Section(header: Text("Export Models")) {
                    Button(action: {
                        exportModels()
                    }) {
                        Text("Export All Models")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .frame(maxHeight: .infinity)

            Spacer()
        }
        .padding()
        .navigationTitle("Model Manager")
    }

    private func exportModels() {
        let panel = NSOpenPanel()
        panel.title = "Select Export Directory"
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.canChooseFiles = false

        panel.begin { response in
            if response == .OK, let directoryURL = panel.url {
                for model in viewModel.models {
                    let sourceURL = viewModel.getDocumentsDirectory().appendingPathComponent("\(model.name).mlmodel")
                    let destinationURL = directoryURL.appendingPathComponent("\(model.name).mlmodel")
                    do {
                        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                        print("Exported \(model.name) to \(destinationURL.path)")
                    } catch {
                        print("Failed to export \(model.name): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
