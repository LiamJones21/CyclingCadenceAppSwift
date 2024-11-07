//
//  SettingsView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CyclingViewModel
    @State private var wheelDiameter: String = ""
    @State private var wheelCircumference: String = ""
    @State private var showDataView = false
    @State private var showGearRatioSheet = false

    // Define possible gear ratios
    let possibleGearRatios = ["1.0", "1.1", "1.2", "1.3", "1.4", "1.5",
                              "1.6", "1.7", "1.8", "1.9", "2.0", "2.1",
                              "2.2", "2.3", "2.4", "2.5", "2.6", "2.7",
                              "2.8", "2.9", "3.0"]

    @Environment(\.editMode) private var editMode

        var body: some View {
            NavigationView {
                Form {
                    Section(header: Text("Bike Specifications")) {
                        HStack {
                            Text("Wheel Diameter (m):")
                                .frame(width: 180, alignment: .leading)
                            TextField("e.g., 0.68", text: $wheelDiameter)
                                .keyboardType(.decimalPad)
                                .onChange(of: wheelDiameter) { newValue in
                                    if let diameter = Double(newValue), diameter > 0 {
                                        let circumference = Double.pi * diameter
                                        wheelCircumference = String(format: "%.4f", circumference)
                                        viewModel.saveWheelDiameter(diameter)
                                    } else {
                                        wheelCircumference = ""
                                    }
                                }
                                .onSubmit {
                                    hideKeyboard()
                                }
                        }

                        HStack {
                            Text("Wheel Circumference (m):")
                                .frame(width: 180, alignment: .leading)
                            TextField("Calculated automatically", text: $wheelCircumference)
                                .disabled(true)
                        }
                    }

//                    Section(header: Text("Gear Ratios")) {
//                        List {
//                            ForEach(viewModel.gearRatios, id: \.self) { ratio in
//                                Text(ratio)
//                            }
//                            .onDelete(perform: deleteGearRatio)
//                            .onMove(perform: moveGearRatio)
//                        }
//
//                        Button(action: {
//                            showGearRatioSheet = true
//                        }) {
//                            Text("Add Gear Ratio")
//                        }
//                        .sheet(isPresented: $showGearRatioSheet) {
//                            AddGearRatioView(viewModel: viewModel, isPresented: $showGearRatioSheet)
//                        }
                    Section(header: Text("Gear Ratios")) {
                                        List {
                                            ForEach(viewModel.gearRatios, id: \.self) { ratio in
                                                Text(ratio)
                                            }
                                            .onDelete(perform: deleteGearRatio)
                                            .onMove(perform: moveGearRatio)
                                        }

                                        Button(action: {
                                            showGearRatioSheet = true
                                        }) {
                                            Text("Add Gear Ratio")
                                        }
                                        .sheet(isPresented: $showGearRatioSheet) {
                                            PossibleGearRatiosView(
                                                possibleGearRatios: possibleGearRatios,
                                                onSelect: { ratio in
                                                    addGearRatio(ratio: ratio)
                                                    showGearRatioSheet = false
                                                }
                                            )
                                        }
                    }

                Section {
                    Button(action: {
                        showDataView = true
                    }) {
                        Text("View Collected Data")
                    }
                    .sheet(isPresented: $showDataView) {
                        DataView(viewModel: viewModel)
                    }
                }

                // Added Activity Log Section
                Section {
                    NavigationLink(destination: ActivityLogView(viewModel: viewModel)) {
                        Text("Activity Log")
                    }
                }
                Section(header: Text("Models")) {
                    NavigationLink(destination: ModelManagerView(viewModel: viewModel)) {
                        Text("Manage Models")
                    }
                }
                Section(header: Text("Models")) {
                    NavigationLink(destination: ModelManagerView(viewModel: viewModel)) {
                        Text("Manage Models")
                    }
                    NavigationLink(destination: ModelTrainingView(cyclingViewModel: CyclingViewModel(), viewModel: ModelTrainingViewModel(cyclingViewModel: CyclingViewModel()), selectedSessionIDs: [])) {
                        Text("Train New Model")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }

    func addGearRatio(ratio: String) {
        if !ratio.isEmpty {
            viewModel.gearRatios.append(ratio)
            saveSettings()
        }
    }


    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.setValue(Double(wheelCircumference), forKey: "wheelCircumference")
        defaults.setValue(Double(wheelDiameter), forKey: "wheelDiameter")
        defaults.setValue(viewModel.gearRatios, forKey: "gearRatios")
    }

    func loadSettings() {
        let defaults = UserDefaults.standard
        wheelCircumference = defaults.double(forKey: "wheelCircumference").description
        if wheelCircumference == "0.0" { wheelCircumference = "2.1" } // Default value

        wheelDiameter = defaults.double(forKey: "wheelDiameter").description
        if wheelDiameter == "0.0" { wheelDiameter = "0.175" } // Default value

        if let savedRatios = defaults.array(forKey: "gearRatios") as? [String] {
            viewModel.gearRatios = savedRatios
        }
    }
    func deleteGearRatio(at offsets: IndexSet) {
            viewModel.gearRatios.remove(atOffsets: offsets)
            viewModel.saveGearRatios()
        }

    func moveGearRatio(from source: IndexSet, to destination: Int) {
        viewModel.gearRatios.move(fromOffsets: source, toOffset: destination)
        viewModel.saveGearRatios()
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
