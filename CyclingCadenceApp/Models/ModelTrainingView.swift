import SwiftUI

struct ModelTrainingView: View {
    @ObservedObject var viewModel: CyclingViewModel
    @State private var selectedTrainingMode = "Manual Training"
    @State private var selectedWindowSize = 100
    @State private var selectedWindowStep = 50
    @State private var includeFFT = false
    @State private var includeWavelet = false
    @State private var selectedModelType = "Decision Tree"
    @State private var maxTrainingTime = 60.0
    @State private var trainingInProgress = false
    @State private var trainingError: Double?

    // For Dynamic mode
    @State private var modelsToTest = ["Decision Tree", "Random Forest"]
    @State private var availableModels = ["Decision Tree", "Random Forest", "Linear Regression", "SVM"]

    var body: some View {
        VStack {
            Picker("Training Mode", selection: $selectedTrainingMode) {
                Text("Manual Training").tag("Manual Training")
                Text("Dynamic").tag("Dynamic")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Form {
                if selectedTrainingMode == "Manual Training" {
                    Section(header: Text("Preprocessing Parameters")) {
                        Stepper(value: $selectedWindowSize, in: 50...500, step: 50) {
                            Text("Window Size: \(selectedWindowSize)")
                        }
                        Stepper(value: $selectedWindowStep, in: 10...250, step: 10) {
                            Text("Window Step: \(selectedWindowStep)")
                        }
                        Toggle("Include FFT", isOn: $includeFFT)
                        Toggle("Include Wavelet", isOn: $includeWavelet)
                    }

                    Section(header: Text("Model Parameters")) {
                        Picker("Model Type", selection: $selectedModelType) {
                            Text("Decision Tree").tag("Decision Tree")
                            Text("Random Forest").tag("Random Forest")
                            Text("Linear Regression").tag("Linear Regression")
                        }
                        Stepper(value: $maxTrainingTime, in: 10...300, step: 10) {
                            Text("Max Training Time: \(Int(maxTrainingTime)) seconds")
                        }
                    }
                } else if selectedTrainingMode == "Dynamic" {
                    Section(header: Text("Preprocessing Options")) {
                        Toggle("Include FFT", isOn: $includeFFT)
                        Toggle("Include Wavelet", isOn: $includeWavelet)
                    }

                    Section(header: Text("Models to Test")) {
                        ForEach(modelsToTest, id: \.self) { model in
                            Text(model)
                        }
                        .onDelete { indices in
                            modelsToTest.remove(atOffsets: indices)
                        }
                        Button(action: {
                            // Logic to add a new model
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add Model")
                            }
                        }
                    }

                    Section(header: Text("Optimization Model")) {
                        Text("The optimization model will automatically select the best model based on performance metrics and parameter tuning.")
                            .font(.subheadline)
                    }

                    Section(header: Text("Training Time")) {
                        Stepper(value: $maxTrainingTime, in: 10...300, step: 10) {
                            Text("Max Training Time: \(Int(maxTrainingTime)) seconds")
                        }
                    }
                }

                Section {
                    Button(action: {
                        trainingInProgress = true
                        // Training action
                    }) {
                        Text(trainingInProgress ? "Training..." : "Train Model")
                    }
                    .disabled(trainingInProgress)
                }

                if let error = trainingError {
                    Section(header: Text("Training Results")) {
                        Text("Model RMSE: \(String(format: "%.2f", error))")
                    }
                }
            }
            .navigationTitle("Train New Model")
        }
    }
}
