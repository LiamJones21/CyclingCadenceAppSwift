//
//  ModelsView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/7/24.
//

// Views/ModelsView.swift

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
                        NavigationLink(destination: ModelDetailView(model: model)) {
                            Text(model.name)
                        }
                    }
                }

                if !viewModel.phoneModels.isEmpty {
                    Section(header: Text("Phone Models")) {
                        ForEach(viewModel.phoneModels) { model in
                            HStack {
                                Text(model.name)
                                Spacer()
                                Button("Download") {
                                    downloadModel(model)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
        }
        .padding()
    }

    func downloadModel(_ model: ModelConfig) {
        // Request the model data from the phone
        if let peerID = viewModel.connectedPeers.first {
            viewModel.requestModel(modelName: model.name)
        }
    }
}
