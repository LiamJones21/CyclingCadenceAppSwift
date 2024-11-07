//
//  MultipleSelectionRow.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/7/24.
//


// Views/MultipleSelectionRow.swift

import SwiftUI

struct MultipleSelectionRow: View {
    let title: String
    let options: [String]
    @Binding var selections: Set<String>

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 5)
            ForEach(options, id: \.self) { option in
                HStack {
                    Text(option)
                    Spacer()
                    if selections.contains(option) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selections.contains(option) {
                        selections.remove(option)
                    } else {
                        selections.insert(option)
                    }
                }
            }
        }
    }
}
