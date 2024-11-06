//
//  HyperparameterOptimizer.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


// HyperparameterOptimizer.swift

import Foundation
import CreateML

class HyperparameterOptimizer {
    let data: [CyclingData]
    let maxTime: Double
    let modelTypes: [String]
    let preprocessingTypes: [String]
    let filteringOptions: [String]
    let scalerOptions: [String]
    let usePCAOptions: [Bool]
    let includeAccelerationOptions: [Bool]
    let includeRotationRateOptions: [Bool]
    let parametersToOptimize: [String]
    let windowSizeOptions: [Int]
    let windowStepOptions: [Int]
    let logHandler: (String) -> Void

    init(
        data: [CyclingData],
        maxTime: Double,
        modelTypes: [String],
        preprocessingTypes: [String],
        filteringOptions: [String],
        scalerOptions: [String],
        usePCAOptions: [Bool],
        includeAccelerationOptions: [Bool],
        includeRotationRateOptions: [Bool],
        parametersToOptimize: [String],
        windowSizeOptions: [Int],
        windowStepOptions: [Int],
        logHandler: @escaping (String) -> Void
    ) {
        self.data = data
        self.maxTime = maxTime
        self.modelTypes = modelTypes
        self.preprocessingTypes = preprocessingTypes
        self.filteringOptions = filteringOptions
        self.scalerOptions = scalerOptions
        self.usePCAOptions = usePCAOptions
        self.includeAccelerationOptions = includeAccelerationOptions
        self.includeRotationRateOptions = includeRotationRateOptions
        self.parametersToOptimize = parametersToOptimize
        self.windowSizeOptions = windowSizeOptions
        self.windowStepOptions = windowStepOptions
        self.logHandler = logHandler
    }

    func optimize(completion: @escaping (MLRegressor?, Double, ModelConfig?) -> Void) {
        let startTime = Date()
        var bestModel: MLRegressor?
        var lowestError: Double = Double.greatestFiniteMagnitude
        var bestConfig: ModelConfig?

        // Define the search space
        var searchSpace = ParameterSearchSpace(
            modelTypes: modelTypes,
            preprocessingTypes: preprocessingTypes,
            filteringOptions: filteringOptions,
            scalerOptions: scalerOptions,
            usePCAOptions: usePCAOptions,
            includeAccelerationOptions: includeAccelerationOptions,
            includeRotationRateOptions: includeRotationRateOptions,
            windowSizeOptions: windowSizeOptions,
            windowStepOptions: windowStepOptions
        )

        // Implement Bayesian optimization using a simple sequential approach
        // Implement Bayesian optimization using a simple sequential approach
        while Date().timeIntervalSince(startTime) < maxTime {
            guard let parameters = searchSpace.nextParameters() else {
                break
            }

            logHandler("Testing parameters: \(parameters)")

            let preprocessor = DataPreprocessor(
                data: data,
                windowSize: parameters.windowSize,
                windowStep: parameters.windowStep,
                preprocessingType: parameters.preprocessingType,
                filtering: parameters.filtering,
                scaler: parameters.scaler,
                usePCA: parameters.usePCA,
                includeAcceleration: parameters.includeAcceleration,
                includeRotationRate: parameters.includeRotationRate
            )

            let features = preprocessor.processedFeatures

            guard let dataTable = try? MLDataTable(dictionary: features) else {
                continue
            }

            let (trainingData, testingData) = dataTable.randomSplit(by: 0.8, seed: 42)
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all

            let model = ModelTrainingViewModel.trainModelStatic(
                modelType: parameters.modelType,
                trainingData: trainingData,
                configuration: configuration
            )

            if let model = model {
                let evaluationMetrics = model.evaluation(on: testingData)
                let error = evaluationMetrics.rootMeanSquaredError

                logHandler("Model: \(parameters.modelType), RMSE: \(error)")
                if error < lowestError {
                    lowestError = error
                    bestModel = model
                    bestConfig = ModelConfig(
                        name: "\(parameters.modelType)_\(Date().timeIntervalSince1970)",
                        config: ModelConfig.Config(
                            windowSize: parameters.windowSize,
                            windowStep: parameters.windowStep,
                            preprocessingType: parameters.preprocessingType,
                            filtering: parameters.filtering,
                            scaler: parameters.scaler,
                            usePCA: parameters.usePCA,
                            includeAcceleration: parameters.includeAcceleration,
                            includeRotationRate: parameters.includeRotationRate
                        )
                    )
                }
            }
        }
        completion(bestModel, lowestError, bestConfig)
    }
}
struct ParameterSearchSpace {
    let modelTypes: [String]
    let preprocessingTypes: [String]
    let filteringOptions: [String]
    let scalerOptions: [String]
    let usePCAOptions: [Bool]
    let includeAccelerationOptions: [Bool]
    let includeRotationRateOptions: [Bool]
    let windowSizeOptions: [Int]
    let windowStepOptions: [Int]

    private var parameterCombinations: [[String: Any]]
    private var currentIndex: Int = 0

    init(
        modelTypes: [String],
        preprocessingTypes: [String],
        filteringOptions: [String],
        scalerOptions: [String],
        usePCAOptions: [Bool],
        includeAccelerationOptions: [Bool],
        includeRotationRateOptions: [Bool],
        windowSizeOptions: [Int],
        windowStepOptions: [Int]
    ) {
        var combinations: [[String: Any]] = []

        for modelType in modelTypes {
            for preprocessingType in preprocessingTypes {
                for filtering in filteringOptions {
                    for scaler in scalerOptions {
                        for usePCA in usePCAOptions {
                            for includeAcceleration in includeAccelerationOptions {
                                for includeRotationRate in includeRotationRateOptions {
                                    for windowSize in windowSizeOptions {
                                        for windowStep in windowStepOptions {
                                            combinations.append([
                                                "modelType": modelType,
                                                "preprocessingType": preprocessingType,
                                                "filtering": filtering,
                                                "scaler": scaler,
                                                "usePCA": usePCA,
                                                "includeAcceleration": includeAcceleration,
                                                "includeRotationRate": includeRotationRate,
                                                "windowSize": windowSize,
                                                "windowStep": windowStep
                                            ])
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        self.parameterCombinations = combinations.shuffled()
    }

    mutating func nextParameters() -> ParameterSet? {
        guard currentIndex < parameterCombinations.count else { return nil }
        let params = parameterCombinations[currentIndex]
        currentIndex += 1
        return ParameterSet(params: params)
    }
}

struct ParameterSet {
    let modelType: String
    let preprocessingType: String
    let filtering: String
    let scaler: String
    let usePCA: Bool
    let includeAcceleration: Bool
    let includeRotationRate: Bool
    let windowSize: Int
    let windowStep: Int

    init?(params: [String: Any]) {
        guard let modelType = params["modelType"] as? String,
              let preprocessingType = params["preprocessingType"] as? String,
              let filtering = params["filtering"] as? String,
              let scaler = params["scaler"] as? String,
              let usePCA = params["usePCA"] as? Bool,
              let includeAcceleration = params["includeAcceleration"] as? Bool,
              let includeRotationRate = params["includeRotationRate"] as? Bool,
              let windowSize = params["windowSize"] as? Int,
              let windowStep = params["windowStep"] as? Int else { return nil }

        self.modelType = modelType
        self.preprocessingType = preprocessingType
        self.filtering = filtering
        self.scaler = scaler
        self.usePCA = usePCA
        self.includeAcceleration = includeAcceleration
        self.includeRotationRate = includeRotationRate
        self.windowSize = windowSize
        self.windowStep = windowStep
    }
}
// Extend ModelTrainingViewModel with a static method
extension ModelTrainingViewModel {
    static func trainModelStatic(
        modelType: String,
        trainingData: MLDataTable,
        configuration: MLModelConfiguration
    ) -> MLRegressor? {
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
            let parameters = MLRegressor.ModelParameters()
            return try? MLRegressor(
                trainingData: trainingData,
                targetColumn: "target",
                parameters: parameters,
                configuration: configuration
            )
        case "LSTM":
            return nil // For simplicity; implement if needed
        default:
            print("Unsupported model type: \(modelType)")
            return nil
        }
    }
}
