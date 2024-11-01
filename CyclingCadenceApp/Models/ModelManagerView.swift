//
//  ModelManagerView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 10/31/24.
// ModelManagerView.swift

import SwiftUI
import UniformTypeIdentifiers

struct ModelManagerView: View {
    @ObservedObject var viewModel: CyclingViewModel
    @State private var showFileImporter = false

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.models.indices, id: \.self) { index in
                    HStack {
                        Text(viewModel.models[index].name)
                        Spacer()
                        Button(action: {
                            viewModel.removeModel(at: index)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
                .onDelete(perform: viewModel.deleteModels(at:))
            }
            .navigationTitle("Manage Models")
            .navigationBarItems(trailing: Button(action: {
                showFileImporter = true
            }) {
                Image(systemName: "plus")
            })
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType(exportedAs: "com.apple.coreml.model")],
                allowsMultipleSelection: false
            ) { result in
                do {
                    let selectedFiles = try result.get()
                    if let fileURL = selectedFiles.first {
                        viewModel.addModel(from: fileURL)
                    }
                } catch {
                    print("Error selecting file: \(error.localizedDescription)")
                }
            }
        }
    }
}

