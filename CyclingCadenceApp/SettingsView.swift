//
//  SettingsView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CyclingViewModel
    @State private var wheelCircumference: String = ""
    @State private var crankLength: String = ""
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
                    TextField("Wheel Circumference (m)", text: $wheelCircumference)
                        .keyboardType(.decimalPad)
                        .onChange(of: wheelCircumference) { _ in
                            saveSettings()
                        }

                    TextField("Crank Length (m)", text: $crankLength)
                        .keyboardType(.decimalPad)
                        .onChange(of: crankLength) { _ in
                            saveSettings()
                        }
                }

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

    func deleteGearRatio(at offsets: IndexSet) {
        viewModel.gearRatios.remove(atOffsets: offsets)
        saveSettings()
    }

    func moveGearRatio(from source: IndexSet, to destination: Int) {
        viewModel.gearRatios.move(fromOffsets: source, toOffset: destination)
        saveSettings()
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.setValue(Double(wheelCircumference), forKey: "wheelCircumference")
        defaults.setValue(Double(crankLength), forKey: "crankLength")
        defaults.setValue(viewModel.gearRatios, forKey: "gearRatios")
    }

    func loadSettings() {
        let defaults = UserDefaults.standard
        wheelCircumference = defaults.double(forKey: "wheelCircumference").description
        if wheelCircumference == "0.0" { wheelCircumference = "2.1" } // Default value

        crankLength = defaults.double(forKey: "crankLength").description
        if crankLength == "0.0" { crankLength = "0.175" } // Default value

        if let savedRatios = defaults.array(forKey: "gearRatios") as? [String] {
            viewModel.gearRatios = savedRatios
        }
    }
}
