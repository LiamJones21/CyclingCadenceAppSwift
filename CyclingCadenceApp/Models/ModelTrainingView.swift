// ModelTrainingView.swift



import SwiftUI

struct ModelTrainingView: View {
    @ObservedObject var cyclingViewModel: CyclingViewModel
    @ObservedObject var viewModel: ModelTrainingViewModel
    @State private var selectedSessionsToTrain: [Session] = []
    @State private var selectedTrainingMode = "Manual Training"
    @State private var selectedWindowSize: Double = 3.0
    @State private var selectedWindowStep: Double = 1.5
    @State private var selectedWindowSizes: [Double] = [3.0]
    @State private var selectedWindowSteps: [Double] = [1.5]
    @State private var selectedModelType = "LightGBM"
    @State private var selectedModelTypes: Set<String> = ["LightGBM"]
    @State private var selectedPreprocessingType = "Normalization" // Changed from "None"
    @State private var selectedPreprocessingTypes: Set<String> = []
    @State private var selectedFilteringOption = "LowPass" // Changed from "None"
    @State private var selectedFilteringOptions: Set<String> = []
    @State private var selectedScaler = "StandardScaler" // Changed from "None"
    @State private var selectedScalers: Set<String> = []
    @State private var usePCA = false
    @State private var maxTrainingTime: Double = 300
    @State private var parametersToOptimize: [String] = []
    @State private var trainingInProgress = false
    @State private var trainingError: Double?
    @State private var trainingLogs: String = ""
    @State private var includeAcceleration = true
    @State private var includeRotationRate = true
    @State private var showSessionSelector = false
    @State private var selectedSessionIDs: [UUID] = []
    @State private var isConnectedToMac = false
    @State private var isKeyboardVisible = false
    
    let sessions: [Session]
    
    let modelTypes = ["LightGBM", "RandomForest", "XGBoost", "MLP", "LSTM"]
    let preprocessingTypes = ["Normalization", "Standardization"]
    let filteringOptions = ["LowPass", "HighPass"]
    let scalerOptions = ["StandardScaler", "MinMaxScaler"]

    init(cyclingViewModel: CyclingViewModel, viewModel: ModelTrainingViewModel, selectedSessionIDs: [UUID]) {
            self.cyclingViewModel = cyclingViewModel
            self.viewModel = viewModel
//            self._selectedSessionsToTrain = State(initialValue: selectedSessionIDs.compactMap { id in
//                viewModel.sessions.first { $0.id == id }
//            })
//        self.selectedSessionsToTrain = .init(selectedSessionIDs.compactMap { id in
//            viewModel.sessions.first { $0.id == id }
//        })
        self.selectedSessionsToTrain = selectedSessionIDs.compactMap { id in
            viewModel.sessions.first { $0.id == id }
        }
        self.sessions = viewModel.sessions
//        print("These are the selected items bright over\(selectedSessionsToTrain.map(\.id))")
//        print("These are the sessions\(sessions)")
    }

    var body: some View {
        VStack {
            HStack {
                Circle()
                    .fill(isConnectedToMac ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(isConnectedToMac ? "Connected to Mac" : "Not Connected")
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
                    Button(
                        action: {
                            trainingInProgress = true
                            trainingLogs = ""
                            let selectedSessionsArray = viewModel.sessions.filter { viewModel.selectedSessions.contains($0.id) }
                            let parameters: [String: Any] = [
                                "windowSizes": selectedWindowSizes.map { Int($0 * 50) },
                                "windowSteps": selectedWindowSteps.map { Int($0 * 50) },
                                "modelTypes": Array(selectedModelTypes),
                                "preprocessingTypes": Array(selectedPreprocessingTypes),
                                "filteringOptions": Array(selectedFilteringOptions),
                                "scalerOptions": Array(selectedScalers),
                                "usePCA": usePCA,
                                "includeAcceleration": includeAcceleration,
                                "includeRotationRate": includeRotationRate,
                                "isAutomatic": selectedTrainingMode == "Automatic Training",
                                "maxTrainingTime": maxTrainingTime,
                                "selectedSessionIDs": selectedSessionsArray.map { $0.id.uuidString }
                            ]
                            // Synchronize settings with connected peers
                            if let peerID = viewModel.connectedPeers.first {
                                viewModel.sendMessage(message: parameters, to: peerID)
                            }
                            trainmodel()
//
                    })
                    {
                        Text(trainingInProgress ? "Training..." : "Train Model")
                    }
                    .disabled(trainingInProgress || viewModel.selectedSessions.isEmpty)
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
        .onAppear {
            // Initialize `selectedSessionsToTrain` based on `selectedSessionIDs`
            selectedSessionsToTrain = selectedSessionIDs.compactMap { id in
                viewModel.sessions.first { $0.id == id }
            }
            // Debug print to check sessions are being set
            print("Selected Sessions on Appear: \(selectedSessionsToTrain)")
            print("all session id: \(viewModel.sessions.map(\.id))")
        }
        .onReceive(viewModel.$connectedPeers) { peers in
            isConnectedToMac = !peers.isEmpty
        }
        .onTapGesture {
            if isKeyboardVisible{
                dismissKeyboard() // Dismiss the keyboard when tapping outside of a text field
            }
        }
    }
    func sendUpdatedSettingsToMac() {
        guard isConnectedToMac else { return }
        let parameters: [String: Any] = [
            "windowSizes": selectedWindowSizes.map { Int($0 * 50) },
            "windowSteps": selectedWindowSteps.map { Int($0 * 50) },
            "modelTypes": Array(selectedModelTypes),
            "preprocessingTypes": Array(selectedPreprocessingTypes),
            "filteringOptions": Array(selectedFilteringOptions),
            "scalerOptions": Array(selectedScalers),
            "usePCA": usePCA,
            "includeAcceleration": includeAcceleration,
            "includeRotationRate": includeRotationRate,
            "isAutomatic": selectedTrainingMode == "Automatic Training",
            "maxTrainingTime": maxTrainingTime,
            "selectedSessionIDs": selectedSessionsToTrain.map { $0.id.uuidString }
        ]
        if let peerID = viewModel.connectedPeers.first {
            let message: [String: Any] = ["type": "trainingSettingsUpdate", "parameters": parameters]
            viewModel.sendMessage(message: message, to: peerID)
        }
    }
    
    func trainmodel() {
        // Set training in progress to true and clear logs
        trainingInProgress = true
        trainingLogs = ""

        // Prepare training parameters to send
        let parameters: [String: Any] = [
            "windowSize": Int(selectedWindowSize * 50),
            "windowStep": Int(selectedWindowStep * 50),
            "modelTypes": Array(selectedModelTypes),
            "preprocessingTypes": Array(selectedPreprocessingTypes),
            "filteringOptions": Array(selectedFilteringOptions),
            "scalerOptions": Array(selectedScalers),
            "usePCA": usePCA,
            "includeAcceleration": includeAcceleration,
            "includeRotationRate": includeRotationRate,
            "isAutomatic": selectedTrainingMode == "Automatic Training",
            "maxTrainingTime": maxTrainingTime,
            "parametersToOptimize": parametersToOptimize,
            "selectedSessionIDs": selectedSessionsToTrain.map { $0.id.uuidString }
        ]
        
        // Send training request to connected Mac (if any)
        if let peerID = viewModel.connectedPeers.first {
            let message: [String: Any] = ["type": "startTraining", "parameters": parameters]
            viewModel.sendMessage(message: message, to: peerID)
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
            
            // Window Sizes Input
            VStack {
                Text("Window Sizes (seconds):")
                ForEach(selectedWindowSizes.indices, id: \.self) { index in
                    HStack {
                        TextField("Window Size", value: $selectedWindowSizes[index], formatter: NumberFormatter())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                        Button(action: {
                            selectedWindowSizes.remove(at: index)
                        }) {
                            Image(systemName: "minus.circle")
                        }
                    }
                }
                Button(action: {
                    selectedWindowSizes.append(0.0) // Add a new size entry
                }) {
                    Text("Add Window Size")
                }
            }
            
            // Window Steps Input
            VStack {
                Text("Window Steps (seconds):")
                ForEach(selectedWindowSteps.indices, id: \.self) { index in
                    HStack {
                        TextField("Window Step", value: $selectedWindowSteps[index], formatter: NumberFormatter())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                        Button(action: {
                            selectedWindowSteps.remove(at: index)
                        }) {
                            Image(systemName: "minus.circle")
                        }
                    }
                }
                Button(action: {
                    selectedWindowSteps.append(0.0) // Add a new step entry
                }) {
                    Text("Add Window Step")
                }
            }
            
            // Max Training Time
            HStack {
                Text("Max Training Time (seconds):")
                Slider(value: $maxTrainingTime, in: 60...1800, step: 60)
                Text("\(Int(maxTrainingTime))")
            }
        }
    }

    func startTraining() {
        trainingInProgress = true
        trainingLogs = ""
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
        // Synchronize settings with connected peers
        if let peerID = viewModel.connectedPeers.first {
            viewModel.sendMessage(message: parameters, to: peerID)
        }
        // Assume the training process is asynchronous and will update `trainingInProgress` accordingly
    }
    func dismissKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
}


    
struct MultipleSelectionRow: View {
    let title: String
    let options: [String]
    @Binding var selections: Set<String>

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 5)
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                HStack {
                    Text(option)
                        .font(.body)
                        .padding(.vertical, 8)
                    Spacer()
                    
                    if selections.contains(option) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
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
        .padding(.vertical, 20)
    }
}
