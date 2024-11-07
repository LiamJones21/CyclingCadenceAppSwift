//
//  TrainingAndLogsView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/7/24.
//


// Views/TrainingAndLogsView.swift

import SwiftUI

struct TrainingAndLogsView: View {
    @ObservedObject var viewModel: ModelTrainingViewModel
    @State private var selectedTrainingMode = "Manual Training"
    @State private var selectedWindowSize: Double = 3.0
    @State private var selectedWindowStep: Double = 1.5
    @State private var selectedModelType = "LightGBM"
    @State private var selectedModelTypes: Set<String> = ["LightGBM"]
    @State private var selectedPreprocessingType = "Normalization"
    @State private var selectedPreprocessingTypes: Set<String> = []
    @State private var selectedFilteringOption = "LowPass"
    @State private var selectedFilteringOptions: Set<String> = []
    @State private var selectedScaler = "StandardScaler"
    @State private var selectedScalers: Set<String> = []
    @State private var usePCA = false
    @State private var maxTrainingTime: Double = 300
    @State private var includeAcceleration = true
    @State private var includeRotationRate = true
    @State private var showSessionSelector = false
    @State private var selectedSessionsToTrain: [Session] = []
    @State private var isConnectedToPhone = false
    
    let modelTypes = ["LightGBM", "RandomForest", "XGBoost", "MLP", "LSTM"]
    let preprocessingTypes = ["Normalization", "Standardization"]
    let filteringOptions = ["LowPass", "HighPass"]
    let scalerOptions = ["StandardScaler", "MinMaxScaler"]
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Circle()
                        .fill(isConnectedToPhone ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(isConnectedToPhone ? "Connected to Phone" : "Not Connected")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                
                HStack {
                    Text("Selected Sessions: \(selectedSessionsToTrain.count)")
                    Spacer()
                    Button(action: {
                        showSessionSelector = true
                    }) {
                        Text("Select Sessions")
                    }
                    .sheet(isPresented: $showSessionSelector) {
                        SessionSelectorView(sessions: viewModel.sessions, selectedSessions: $selectedSessionsToTrain)
                    }
                }
                .padding()
                
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
                            startTraining()
                        }) {
                            Text(viewModel.trainingInProgress ? "Training..." : "Start Training")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.trainingInProgress ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(viewModel.trainingInProgress || selectedSessionsToTrain.isEmpty)
                    }
                }
                .padding()
                
                Spacer()
            }
            .frame(width: 400)
            .padding()
            
            Divider()
            
            VStack(alignment: .leading) {
                Text("Training Logs")
                    .font(.headline)
                    .padding(.bottom, 5)
                
                ScrollView {
                    Text(viewModel.trainingLogs)
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(white: 0.95))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            isConnectedToPhone = !viewModel.connectedPeers.isEmpty
        }
        .onReceive(viewModel.$connectedPeers) { peers in
            isConnectedToPhone = !peers.isEmpty
        }
    }
    
    var manualTrainingSection: some View {
        Section(header: Text("Model Parameters")) {
            // Model Type Dropdown
            Picker("Model Type", selection: $selectedModelType) {
                ForEach(modelTypes, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            
            // Preprocessing Type Dropdown
            Picker("Preprocessing Type", selection: $selectedPreprocessingType) {
                ForEach(preprocessingTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            
            // Filtering Option Dropdown
            Picker("Filtering Option", selection: $selectedFilteringOption) {
                ForEach(filteringOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            
            // Scaler Dropdown
            Picker("Scaler", selection: $selectedScaler) {
                ForEach(scalerOptions, id: \.self) { scaler in
                    Text(scaler).tag(scaler)
                }
            }
            
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
            // Model Types Multi-Select
            MultipleSelectionRow(title: "Model Types", options: modelTypes, selections: $selectedModelTypes)
            
            // Preprocessing Types Multi-Select
            MultipleSelectionRow(title: "Preprocessing Types", options: preprocessingTypes, selections: $selectedPreprocessingTypes)
            
            // Filtering Options Multi-Select
            MultipleSelectionRow(title: "Filtering Options", options: filteringOptions, selections: $selectedFilteringOptions)
            
            // Scalers Multi-Select
            MultipleSelectionRow(title: "Scalers", options: scalerOptions, selections: $selectedScalers)
            
            // PCA
            Toggle("Use PCA", isOn: $usePCA)
            
            // Include Acceleration and Rotation Rate
            Toggle("Include Acceleration Data", isOn: $includeAcceleration)
            Toggle("Include Rotation Rate Data", isOn: $includeRotationRate)
            
            // Max Training Time
            HStack {
                Text("Max Training Time (seconds):")
                Slider(value: $maxTrainingTime, in: 60...1800, step: 60)
                Text("\(Int(maxTrainingTime))")
            }
        }
    }
    
    func startTraining() {
        let parameters: [String: Any] = [
            "windowSize": Int(selectedWindowSize * 50),
            "windowStep": Int(selectedWindowStep * 50),
            "modelTypes": selectedTrainingMode == "Manual Training" ? [selectedModelType] : Array(selectedModelTypes),
            "preprocessingTypes": selectedTrainingMode == "Manual Training" ? [selectedPreprocessingType] : Array(selectedPreprocessingTypes),
            "filteringOptions": selectedTrainingMode == "Manual Training" ? [selectedFilteringOption] : Array(selectedFilteringOptions),
            "scalerOptions": selectedTrainingMode == "Manual Training" ? [selectedScaler] : Array(selectedScalers),
            "usePCA": usePCA,
            "includeAcceleration": includeAcceleration,
            "includeRotationRate": includeRotationRate,
            "isAutomatic": selectedTrainingMode == "Automatic Training",
            "maxTrainingTime": maxTrainingTime,
            "selectedSessionIDs": selectedSessionsToTrain.map { $0.id.uuidString }
        ]
        
        // Send settings to connected phone
        if let peerID = viewModel.connectedPeers.first {
            let message: [String: Any] = ["type": "trainingSettingsUpdate", "parameters": parameters]
            viewModel.sendMessage(message: message, to: peerID)
        }
        
        viewModel.startTraining(with: parameters, from: viewModel.connectedPeers.first!)
    }
}
