//
//  PossibleGearRatiosView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
//


// PossibleGearRatiosView.swift

import SwiftUI
struct PossibleGearRatiosView: View {
    @State private var selectedRatio: String = ""
    @State private var customRatio: String = ""
    let possibleGearRatios: [String]
    var onSelect: (String) -> Void

    var body: some View {
        NavigationView {
            VStack {
                Picker("Select Gear Ratio", selection: $selectedRatio) {
                    ForEach(possibleGearRatios, id: \.self) { ratio in
                        Text(ratio).tag(ratio)
                    }
                    Text("Custom").tag("Custom")
                }
                .pickerStyle(WheelPickerStyle())
                .labelsHidden()
                .frame(maxHeight: 200)

                if selectedRatio == "Custom" {
                    TextField("Enter Gear Ratio (e.g., 38/34 or 38.0/16.3)", text: $customRatio)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                }

                Button(action: {
                    let ratioToAdd = selectedRatio == "Custom" ? customRatio : selectedRatio
                    onSelect(ratioToAdd)
                }) {
                    Text("Add")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding()
                }
            }
            .navigationTitle("Select Gear Ratio")
            .navigationBarItems(trailing: Button("Cancel") {
                // Dismiss the sheet
            })
        }
    }
}

// PossibleGearRatiosView.swift
//
//import SwiftUI
//
//struct PossibleGearRatiosView: View {
//    let possibleGearRatios: [String]
//    var onSelect: (String) -> Void
//
//    var body: some View {
//        NavigationView {
//            List(possibleGearRatios, id: \.self) { ratio in
//                Button(action: {
//                    onSelect(ratio)
//                }) {
//                    HStack {
//                        Text(ratio)
//                        Spacer()
//                        Image(systemName: "plus.circle.fill")
//                            .foregroundColor(.green)
//                    }
//                }
//            }
//            .navigationTitle("Select Gear Ratio")
//        }
//    }
//}
