//
//  ContentView.swift
//  CyclingTrainer
//
//  Created by Jones, Liam on 11/6/24.
//
import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = CyclingTrainerViewModel()

    // Training parameters
    @State private var selectedTrainingMode = "Manual Training"
    @State private var selectedWindowSize: Double = 3.0
    @State private var selectedWindowStep: Double = 1.5
    @State private var selectedModelTypes: Set<String> = ["LightGBM"]
    @State private var selectedPreprocessingTypes: Set<String> = ["None"]
    @State private var selectedFilteringOptions: Set<String> = ["None"]
    @State private var selectedScalers: Set<String> = ["None"]
    @State private var usePCA = false
    @State private var maxTrainingTime: Double = 300
    @State private var includeAcceleration = true
    @State private var includeRotationRate = true

    let modelTypes = ["LightGBM", "RandomForest", "XGBoost", "MLP", "LSTM"]
    let preprocessingTypes = ["None", "Normalization", "Standardization"]
    let filteringOptions = ["None", "LowPass", "HighPass"]
    let scalerOptions = ["None", "StandardScaler", "MinMaxScaler"]

    var body: some View {
        NavigationView {
            VStack {
                // Session Selection
                List(selection: $viewModel.selectedSessions) {
                    ForEach(viewModel.sessions) { session in
                        Text(session.name ?? session.dateFormatted)
                    }
                }
                .frame(width: 200)
                .listStyle(SidebarListStyle())
                .navigationTitle("Sessions")

                // Training Configuration
                Form {
                    Picker("Training Mode", selection: $selectedTrainingMode) {
                        Text("Manual Training").tag("Manual Training")
                        Text("Automatic Training").tag("Automatic Training")
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    // Model Parameters
                    MultipleSelectionRow(title: "Model Types", options: modelTypes, selections: $selectedModelTypes)
                    MultipleSelectionRow(title: "Preprocessing Types", options: preprocessingTypes, selections: $selectedPreprocessingTypes)
                    MultipleSelectionRow(title: "Filtering Options", options: filteringOptions, selections: $selectedFilteringOptions)
                    MultipleSelectionRow(title: "Scalers", options: scalerOptions, selections: $selectedScalers)
                    Toggle("Use PCA", isOn: $usePCA)
                    Toggle("Include Acceleration Data", isOn: $includeAcceleration)
                    Toggle("Include Rotation Rate Data", isOn: $includeRotationRate)

                    HStack {
                        Text("Window Size (seconds):")
                        Slider(value: $selectedWindowSize, in: 1...10, step: 0.5)
                        Text("\(String(format: "%.1f", selectedWindowSize))")
                    }
                    HStack {
                        Text("Window Step (seconds):")
                        Slider(value: $selectedWindowStep, in: 0.5...5, step: 0.5)
                        Text("\(String(format: "%.1f", selectedWindowStep))")
                    }
                    HStack {
                        Text("Max Training Time (seconds):")
                        Slider(value: $maxTrainingTime, in: 60...1800, step: 60)
                        Text("\(Int(maxTrainingTime))")
                    }

                    Button(action: {
                        let selectedSessionsArray = viewModel.sessions.filter { viewModel.selectedSessions.contains($0.id) }
                        viewModel.trainModel(
                            windowSize: Int(selectedWindowSize * 50),
                            windowStep: Int(selectedWindowStep * 50),
                            modelTypes: Array(selectedModelTypes),
                            preprocessingTypes: Array(selectedPreprocessingTypes),
                            filteringOptions: Array(selectedFilteringOptions),
                            scalerOptions: Array(selectedScalers),
                            usePCA: usePCA,
                            includeAcceleration: includeAcceleration,
                            includeRotationRate: includeRotationRate,
                            isAutomatic: selectedTrainingMode == "Automatic Training",
                            maxTrainingTime: maxTrainingTime,
                            parametersToOptimize: [], // Implement parameter selection if needed
                            selectedSessions: selectedSessionsArray
                        ) { error in
                            // Handle completion
                        }
                    }) {
                        Text(viewModel.trainingInProgress ? "Training..." : "Train Model")
                    }
                    .disabled(viewModel.trainingInProgress || viewModel.selectedSessions.isEmpty)
                }
                .padding()

                // Training Logs
                VStack {
                    Text("Training Logs")
                        .font(.headline)
                    ScrollView {
                        Text(viewModel.trainingLogs)
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }

            // Right Sidebar: Models and Actions
            VStack {
                List(viewModel.models) { model in
                    HStack {
                        Text(model.name)
                        Spacer()
                        Button("Send to Phone") {
                            viewModel.sendModelToPhone(model: model)
                        }
                    }
                }
                .frame(minWidth: 200)
                .listStyle(SidebarListStyle())
                .navigationTitle("Models")
            }
        }
    }
}

struct MultipleSelectionRow: View {
    let title: String
    let options: [String]
    @Binding var selections: Set<String>

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
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
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
