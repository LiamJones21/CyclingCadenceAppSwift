//
//  ModelTrainingViewModel.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


// ModelTrainingViewModel.swift

import Foundation
import SwiftUI
import CreateML
import Accelerate
import CoreML

class ModelTrainingViewModel: ObservableObject {
    @Published var models: [ModelConfig] = []
    @Published var selectedModelIndex: Int?
    @Published var trainingLogs: String = ""
    @Published var trainingInProgress: Bool = false
    @Published var trainingError: Double?
    @Published var selectedSessions: Set<UUID> = []
    @Published var sessions: [Session] = []

    init(sessions: [Session]) {
        self.sessions = sessions
        loadModels()
    }

    func loadModels() {
        // Similar to the loadModels method in CyclingViewModel
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
        logHandler: @escaping (String) -> Void,
        completion: @escaping (Double?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let startTime = Date()
            guard let data = self.loadTrainingData(from: selectedSessions) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            var bestModel: MLRegressor?
            var lowestError: Double = Double.greatestFiniteMagnitude
            var bestModelConfig: ModelConfig?

            if isAutomatic {
                // Implement Bayesian optimization
                let optimizer = HyperparameterOptimizer(
                    data: data,
                    maxTime: maxTrainingTime,
                    modelTypes: modelTypes,
                    preprocessingTypes: preprocessingTypes,
                    filteringOptions: filteringOptions,
                    scalerOptions: scalerOptions,
                    usePCAOptions: [usePCA],
                    includeAccelerationOptions: [includeAcceleration],
                    includeRotationRateOptions: [includeRotationRate],
                    parametersToOptimize: parametersToOptimize,
                    windowSizeOptions: [windowSize],
                    windowStepOptions: [windowStep],
                    logHandler: logHandler
                )

                optimizer.optimize { model, error, config in
                    bestModel = model
                    lowestError = error
                    bestModelConfig = config
                    DispatchQueue.main.async {
                        self.saveModel(model: model, config: config)
                        completion(lowestError)
                    }
                }
            } else {
                // Manual training
                for modelType in modelTypes {
                    for preprocessingType in preprocessingTypes {
                        for filtering in filteringOptions {
                            for scaler in scalerOptions {
                                let preprocessor = DataPreprocessor(
                                    data: data,
                                    windowSize: windowSize,
                                    windowStep: windowStep,
                                    preprocessingType: preprocessingType,
                                    filtering: filtering,
                                    scaler: scaler,
                                    usePCA: usePCA,
                                    includeAcceleration: includeAcceleration,
                                    includeRotationRate: includeRotationRate
                                )

                                let features = preprocessor.processedFeatures

                                guard let dataTable = try? MLDataTable(dictionary: features) else {
                                    continue
                                }
                                let (trainingData, testingData) = dataTable.randomSplit(by: 0.8, seed: 42)
                                let configuration = MLModelConfiguration()
                                configuration.computeUnits = .all

                                let model = self.trainModelOfType(
                                    modelType,
                                    trainingData: trainingData,
                                    configuration: configuration
                                )

                                if let model = model {
                                    let evaluationMetrics = model.evaluation(on: testingData)
                                    let error = evaluationMetrics.rootMeanSquaredError

                                    logHandler("Model: \(modelType), RMSE: \(error)")
                                    if error < lowestError {
                                        lowestError = error
                                        bestModel = model
                                        bestModelConfig = ModelConfig(
                                            name: "\(modelType)_\(Date().timeIntervalSince1970)",
                                            config: ModelConfig.Config(
                                                windowSize: windowSize,
                                                windowStep: windowStep,
                                                preprocessingType: preprocessingType,
                                                filtering: filtering,
                                                scaler: scaler,
                                                usePCA: usePCA,
                                                includeAcceleration: includeAcceleration,
                                                includeRotationRate: includeRotationRate
                                            )
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.saveModel(model: bestModel, config: bestModelConfig)
                    completion(lowestError)
                }
            }
        }
    }

    private func trainModelOfType(_ modelType: String, trainingData: MLDataTable, configuration: MLModelConfiguration) -> MLRegressor? {
        switch modelType {
        case "LightGBM", "XGBoost":
            let parameters = MLBoostedTreeRegressor.ModelParameters()
            return try? MLBoostedTreeRegressor(
                trainingData: trainingData,
                targetColumn: "target",
                parameters: parameters,
                configuration: configuration
            )
        case "RandomForest":
            let parameters = MLRandomForestRegressor.ModelParameters()
            return try? MLRandomForestRegressor(
                trainingData: trainingData,
                targetColumn: "target",
                parameters: parameters,
                configuration: configuration
            )
        case "MLP":
            let parameters = MLNeuralNetworkRegressor.ModelParameters()
            return try? MLNeuralNetworkRegressor(
                trainingData: trainingData,
                targetColumn: "target",
                parameters: parameters,
                configuration: configuration
            )
        case "LSTM":
            return self.trainLSTMModel(trainingData: trainingData, configuration: configuration)
        default:
            print("Unsupported model type: \(modelType)")
            return nil
        }
    }

    private func trainLSTMModel(trainingData: MLDataTable, configuration: MLModelConfiguration) -> MLRegressor? {
        // Implement LSTM training
        // Create MLSequenceRegressor
        let parameters = MLSequenceRegressor.ModelParameters()
        return try? MLSequenceRegressor(
            trainingData: trainingData,
            targetColumn: "target",
            parameters: parameters,
            configuration: configuration
        )
    }

    func loadTrainingData(from sessions: [Session]) -> [CyclingData]? {
        return sessions.flatMap { $0.data }
    }

    private func saveModel(model: MLRegressor?, config: ModelConfig?) {
        guard let model = model, let config = config else { return }
        let modelName = config.name
        let saveURL = getDocumentsDirectory().appendingPathComponent("\(modelName).mlmodel")
        do {
            try model.write(to: saveURL)
            models.append(config)
            saveModelsToFile()
        } catch {
            print("Error saving model: \(error.localizedDescription)")
        }

        // Save model config
        let configURL = getDocumentsDirectory().appendingPathComponent("\(modelName).json")
        do {
            let encoder = JSONEncoder()
            let configData = try encoder.encode(config.config)
            try configData.write(to: configURL)
        } catch {
            print("Error saving model config: \(error.localizedDescription)")
        }
    }

    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func saveModelsToFile() {
        let fileName = "ModelsData.json"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(models)
            try data.write(to: fileURL)
            print("Models saved to \(fileURL)")
        } catch {
            print("Error saving models: \(error)")
        }
    }

    // ... (Other methods if needed)
}
