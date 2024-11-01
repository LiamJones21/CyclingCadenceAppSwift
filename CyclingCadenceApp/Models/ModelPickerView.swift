//
//  ModelPickerView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 10/31/24.
//


// ModelPickerView.swift

import SwiftUI

struct ModelPickerView: View {
    @ObservedObject var viewModel: CyclingViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.models.indices, id: \.self) { index in
                    Button(action: {
                        viewModel.selectedModelIndex = index
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(viewModel.models[index].name)
                            Spacer()
                            if viewModel.selectedModelIndex == index {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Model")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

