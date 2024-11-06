// ModelTrainingView.swift

import SwiftUI

struct ModelTrainingView: View {
    @ObservedObject var viewModel: ModelTrainingViewModel
    @State private var selectedTrainingMode = "Manual Training"
    @State private var selectedWindowSize: Double = 3.0
    @State private var selectedWindowStep: Double = 1.5
    @State private var selectedModelTypes: Set<String> = ["LightGBM"]
    @State private var selectedPreprocessingTypes: Set<String> = ["None"]
    @State private var selectedFilteringOptions: Set<String> = ["None"]
    @State private var selectedScalers: Set<String> = ["None"]
    @State private var usePCA = false
    @State private var maxTrainingTime: Double = 300
    @State private var parametersToOptimize: [String] = []
    @State private var trainingInProgress = false
    @State private var trainingError: Double?
    @State private var trainingLogs: String = ""
    @State private var showParameterSelection = false
    @State private var includeAcceleration = true
    @State private var includeRotationRate = true

    @State private var selectedSessions: Set<UUID> = []

    let modelTypes = ["LightGBM", "RandomForest", "XGBoost", "MLP", "LSTM"]
    let preprocessingTypes = ["None", "Normalization", "Standardization"]
    let filteringOptions = ["None", "LowPass", "HighPass"]
    let scalerOptions = ["None", "StandardScaler", "MinMaxScaler"]

    var body: some View {
        VStack {
            // Session Selection
            List(viewModel.sessions, id: \.id, selection: $selectedSessions) { session in
                Text(session.name ?? session.dateFormatted)
            }
            .frame(height: 200)
            .navigationTitle("Select Sessions")

            Picker("Training Mode", selection: $selectedTrainingMode) {
                Text("Manual Training").tag("Manual Training")
                Text("Automatic Training").tag("Automatic Training")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Form {
                if selectedTrainingMode == "Manual Training" {
                    manualTrainingSection
                } else {
                    automaticTrainingSection
                }

                Section {
                    Button(action: {
                        trainingInProgress = true
                        trainingLogs = ""
                        let selectedSessionsArray = viewModel.sessions.filter { selectedSessions.contains($0.id) }
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
                            parametersToOptimize: parametersToOptimize,
                            selectedSessions: selectedSessionsArray,
                            logHandler: { log in
                                DispatchQueue.main.async {
                                    trainingLogs.append(contentsOf: log + "\n")
                                }
                            },
                            completion: { error in
                                DispatchQueue.main.async {
                                    trainingError = error
                                    trainingInProgress = false
                                }
                            })
                    }) {
                        Text(trainingInProgress ? "Training..." : "Train Model")
                    }
                    .disabled(trainingInProgress || selectedSessions.isEmpty)
                }

                if let error = trainingError {
                    Section(header: Text("Training Results")) {
                        Text("Best Model RMSE: \(String(format: "%.2f", error))")
                    }
                }

                if !trainingLogs.isEmpty {
                    Section(header: Text("Training Logs")) {
                        ScrollView {
                            Text(trainingLogs)
                                .font(.system(size: 12))
                        }
                        .frame(height: 200)
                    }
                }
            }
            .navigationTitle("Train New Model")
        }
        .toolbar {
            EditButton()
        }
    }

    var manualTrainingSection: some View {
        Section(header: Text("Model Parameters")) {
            // Model Types
            MultipleSelectionRow(title: "Model Types", options: modelTypes, selections: $selectedModelTypes)

            // Preprocessing Types
            MultipleSelectionRow(title: "Preprocessing Types", options: preprocessingTypes, selections: $selectedPreprocessingTypes)

            // Filtering Options
            MultipleSelectionRow(title: "Filtering Options", options: filteringOptions, selections: $selectedFilteringOptions)

            // Scalers
            MultipleSelectionRow(title: "Scalers", options: scalerOptions, selections: $selectedScalers)

            // PCA
            Toggle("Use PCA", isOn: $usePCA)

            // Include Acceleration and Rotation Rate
            Toggle("Include Acceleration Data", isOn: $includeAcceleration)
            Toggle("Include Rotation Rate Data", isOn: $includeRotationRate)

            // Window Size
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
        }
    }

    var automaticTrainingSection: some View {
        Section(header: Text("Parameters to Optimize")) {
            // Model Types
            MultipleSelectionRow(title: "Model Types", options: modelTypes, selections: $selectedModelTypes)

            // Preprocessing Types
            MultipleSelectionRow(title: "Preprocessing Types", options: preprocessingTypes, selections: $selectedPreprocessingTypes)

            // Filtering Options
            MultipleSelectionRow(title: "Filtering Options", options: filteringOptions, selections: $selectedFilteringOptions)

            // Scalers
            MultipleSelectionRow(title: "Scalers", options: scalerOptions, selections: $selectedScalers)

            // PCA
            Toggle("Use PCA", isOn: $usePCA)

            // Include Acceleration and Rotation Rate
            Toggle("Include Acceleration Data", isOn: $includeAcceleration)
            Toggle("Include Rotation Rate Data", isOn: $includeRotationRate)

            // Window Size
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

            // Max Training Time
            HStack {
                Text("Max Training Time (seconds):")
                Slider(value: $maxTrainingTime, in: 60...1800, step: 60)
                Text("\(Int(maxTrainingTime))")
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
            }
        }
    }
}
