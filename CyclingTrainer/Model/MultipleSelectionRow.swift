//
//  MultipleSelectionRow.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


import SwiftUI

struct MultipleSelectionRow: View {
    let title: String
    let options: [String]
    @Binding var selections: Set<String>

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            ForEach(options, id: \.self) { option in
                Button(action: {
                    if selections.contains(option) {
                        selections.remove(option)
                    } else {
                        selections.insert(option)
                    }
                }) {
                    HStack {
                        Text(option)
                        Spacer()
                        if selections.contains(option) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
