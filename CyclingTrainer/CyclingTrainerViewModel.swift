//
//  CyclingTrainerViewModel.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


import Foundation
import Combine
import CreateML

class CyclingTrainerViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var models: [ModelConfig] = []
    @Published var trainingLogs: String = ""
    @Published var trainingInProgress: Bool = false
    @Published var trainingError: Double?
    @Published var selectedSessions: Set<UUID> = []
    @Published var availableModels: [String] = []

    // Networking properties
    private var server: ModelServer?

    init() {
        loadSessions()
        loadModels()
        setupServer()
    }

    // Load sessions from file or database
    func loadSessions() {
        // Implement session loading logic
        // For this example, we'll assume sessions are loaded
    }

    // Load models from local storage
    func loadModels() {
        // Implement model loading logic
        // For this example, we'll assume models are loaded
    }

    // Setup the server to communicate with the iOS app
    func setupServer() {
        server = ModelServer(viewModel: self)
        server?.start()
    }

    // Training function (similar to previous implementations)
    func trainModel(
        windowSize: Int,
        windowStep: Int,
        modelTypes: [String],
        preprocessingTypes: [String],
        filteringOptions: [String],
        scalerOptions: [String],
        usePCA: Bool,
        includeAcceleration: Bool,
        includeRotationRate: Bool,
        isAutomatic: Bool,
        maxTrainingTime: Double,
        parametersToOptimize: [String],
        selectedSessions: [Session],
        completion: @escaping (Double?) -> Void
    ) {
        trainingInProgress = true
        trainingLogs = ""
        DispatchQueue.global(qos: .userInitiated).async {
            // Implement training logic using CreateML
            // Update trainingLogs and trainingError accordingly
            // For brevity, the detailed implementation is omitted here
            DispatchQueue.main.async {
                self.trainingInProgress = false
                completion(self.trainingError)
            }
        }
    }

    // Send model to the connected iOS app
    func sendModelToPhone(model: ModelConfig) {
        server?.sendModel(model: model)
    }

    func trainModel(
        windowSize: Int,
        windowStep: Int,
        modelTypes: [String],
        preprocessingTypes: [String],
        filteringOptions: [String],
        scalerOptions: [String],
        usePCA: Bool,
        includeAcceleration: Bool,
        includeRotationRate: Bool,
        isAutomatic: Bool,
        maxTrainingTime: Double,
        parametersToOptimize: [String],
        selectedSessions: [Session],
        completion: @escaping (Double?) -> Void
    ) {
        trainingInProgress = true
        trainingLogs = ""
        DispatchQueue.global(qos: .userInitiated).async {
            let data = selectedSessions.flatMap { $0.data }

            // Preprocess data and extract features
            let preprocessor = DataPreprocessor(
                data: data,
                windowSize: windowSize,
                windowStep: windowStep,
                preprocessingType: preprocessingTypes.first ?? "None",
                filtering: filteringOptions.first ?? "None",
                scaler: scalerOptions.first ?? "None",
                usePCA: usePCA,
                includeAcceleration: includeAcceleration,
                includeRotationRate: includeRotationRate
            )

            let features = preprocessor.processedFeatures

            guard let dataTable = try? MLDataTable(dictionary: features) else {
                DispatchQueue.main.async {
                    self.trainingInProgress = false
                    completion(nil)
                }
                return
            }

            let (trainingData, testingData) = dataTable.randomSplit(by: 0.8, seed: 42)
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all

            do {
                let regressor = try MLRegressor(trainingData: trainingData, targetColumn: "target")
                let evaluationMetrics = regressor.evaluation(on: testingData)
                let error = evaluationMetrics.rootMeanSquaredError

                DispatchQueue.main.async {
                    self.trainingInProgress = false
                    self.trainingError = error
                    self.trainingLogs = "Training completed with RMSE: \(error)"
                    // Save model and update models list
                    let modelName = "Model_\(Date().timeIntervalSince1970)"
                    let modelURL = self.getDocumentsDirectory().appendingPathComponent("\(modelName).mlmodel")
                    try regressor.write(to: modelURL)
                    let config = ModelConfig.Config(
                        windowSize: windowSize,
                        windowStep: windowStep,
                        preprocessingType: preprocessingTypes.first ?? "None",
                        filtering: filteringOptions.first ?? "None",
                        scaler: scalerOptions.first ?? "None",
                        usePCA: usePCA,
                        includeAcceleration: includeAcceleration,
                        includeRotationRate: includeRotationRate
                    )
                    let modelConfig = ModelConfig(name: modelName, config: config)
                    self.models.append(modelConfig)
                    completion(error)
                }
            } catch {
                DispatchQueue.main.async {
                    self.trainingInProgress = false
                    self.trainingLogs = "Training failed: \(error.localizedDescription)"
                    completion(nil)
                }
            }
        }
    }
}
