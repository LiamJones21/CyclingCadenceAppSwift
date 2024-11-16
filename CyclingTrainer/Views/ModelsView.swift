//
//  ModelsView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/7/24.
//

// ModelsView.swift
import SwiftUI

struct ModelsView: View {
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
                            Text(model.name)
                            Spacer()
                            Button(action: {
                                // Send model to phone
                                sendModelToPhone(model)
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                if !viewModel.phoneModels.isEmpty {
                    Section(header: Text("Phone Models")) {
                        ForEach(viewModel.phoneModels) { model in
                            HStack {
                                Text(model.name)
                                Spacer()
                                Button(action: {
                                    // Request model from phone
                                    requestModelFromPhone(model)
                                }) {
                                    Image(systemName: "square.and.arrow.down")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        viewModel.requestModelsFromPhone()
                    }) {
                        Label("Refresh Phone Models", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .padding()
    }

    func sendModelToPhone(_ model: ModelConfig) {
        // Implement sending model to phone
        if let peerID = viewModel.connectedPeers.first {
            viewModel.sendModel(model: model, to: peerID)
        }
    }

    func requestModelFromPhone(_ model: ModelConfig) {
        // Implement requesting model from phone
        if let peerID = viewModel.connectedPeers.first {
            let message: [String: Any] = ["type": "requestModel", "modelName": model.name]
            viewModel.sendMessage(message: message, to: peerID)
        }
    }
}
