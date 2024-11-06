//
//  DataPreprocessor.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


// DataPreprocessor.swift

import Foundation
import CreateML
import Accelerate

class DataPreprocessor {
    let data: [CyclingData]
    let windowSize: Int
    let windowStep: Int
    let preprocessingType: String
    let filtering: String
    let scaler: String
    let usePCA: Bool
    let includeAcceleration: Bool
    let includeRotationRate: Bool

    var processedFeatures: [String: [MLDataValueConvertible]] = [:]
    private var pcaTransform: PCA?

    init(
        data: [CyclingData],
        windowSize: Int,
        windowStep: Int,
        preprocessingType: String,
        filtering: String,
        scaler: String,
        usePCA: Bool,
        includeAcceleration: Bool,
        includeRotationRate: Bool
    ) {
        self.data = data
        self.windowSize = windowSize
        self.windowStep = windowStep
        self.preprocessingType = preprocessingType
        self.filtering = filtering
        self.scaler = scaler
        self.usePCA = usePCA
        self.includeAcceleration = includeAcceleration
        self.includeRotationRate = includeRotationRate

        process()
    }

    private func process() {
        // Windowing
        let windows = stride(from: 0, to: data.count - windowSize, by: windowStep).map {
            Array(data[$0..<$0 + windowSize])
        }

        // Feature arrays
        var featureArrays: [[Double]] = []
        var targets: [Double] = []

        for window in windows {
            // Extract features from the window
            var features: [Double] = []

            if includeAcceleration {
                // Accelerometer data
                let accelX = window.map { $0.sensorData.accelerationX }
                let accelY = window.map { $0.sensorData.accelerationY }
                let accelZ = window.map { $0.sensorData.accelerationZ }

                features.append(contentsOf: extractStatistics(data: accelX))
                features.append(contentsOf: extractStatistics(data: accelY))
                features.append(contentsOf: extractStatistics(data: accelZ))
            }

            if includeRotationRate {
                // Rotation rate data
                let rotX = window.map { $0.sensorData.rotationRateX }
                let rotY = window.map { $0.sensorData.rotationRateY }
                let rotZ = window.map { $0.sensorData.rotationRateZ }

                features.append(contentsOf: extractStatistics(data: rotX))
                features.append(contentsOf: extractStatistics(data: rotY))
                features.append(contentsOf: extractStatistics(data: rotZ))
            }

            // Additional features can be added here

            featureArrays.append(features)
            // Assuming target is cadence
            targets.append(window.map { $0.cadence }.average())
        }

        // Scaling
        if scaler != "None" {
            featureArrays = applyScaling(features: featureArrays, scaler: scaler)
        }

        // PCA
        if usePCA {
            featureArrays = applyPCA(features: featureArrays)
        }

        // Convert feature arrays to MLMultiArray
        var mlFeatureArrays: [MLMultiArray] = []
        for features in featureArrays {
            if let mlArray = try? MLMultiArray(features) {
                mlFeatureArrays.append(mlArray)
            }
        }

        // Prepare features dictionary
        processedFeatures = [
            "features": mlFeatureArrays,
            "target": targets
        ]
    }

    func extractFeatures() -> [Double] {
        // Combine features from data
        var features: [Double] = []

        if includeAcceleration {
            let accelX = data.map { $0.sensorData.accelerationX }
            let accelY = data.map { $0.sensorData.accelerationY }
            let accelZ = data.map { $0.sensorData.accelerationZ }

            features.append(contentsOf: extractStatistics(data: accelX))
            features.append(contentsOf: extractStatistics(data: accelY))
            features.append(contentsOf: extractStatistics(data: accelZ))
        }

        if includeRotationRate {
            let rotX = data.map { $0.sensorData.rotationRateX }
            let rotY = data.map { $0.sensorData.rotationRateY }
            let rotZ = data.map { $0.sensorData.rotationRateZ }

            features.append(contentsOf: extractStatistics(data: rotX))
            features.append(contentsOf: extractStatistics(data: rotY))
            features.append(contentsOf: extractStatistics(data: rotZ))
        }

        // Scaling
        if scaler != "None" {
            features = applyScalingToSingle(features: features, scaler: scaler)
        }

        // PCA
        if usePCA, let pca = pcaTransform {
            features = pca.transform(vector: features)
        }

        return features
    }

    private func extractStatistics(data: [Double]) -> [Double] {
        let mean = data.average()
        let std = data.standardDeviation()
        let min = data.min() ?? 0.0
        let max = data.max() ?? 0.0
        return [mean, std, min, max]
    }

    private func applyScaling(features: [[Double]], scaler: String) -> [[Double]] {
        var scaledFeatures = features
        let transposed = transpose(matrix: features)

        if scaler == "StandardScaler" {
            var scaledTransposed: [[Double]] = []
            for column in transposed {
                let mean = column.average()
                let std = column.standardDeviation()
                let scaledColumn = column.map { ($0 - mean) / std }
                scaledTransposed.append(scaledColumn)
            }
            scaledFeatures = transpose(matrix: scaledTransposed)
        } else if scaler == "MinMaxScaler" {
            var scaledTransposed: [[Double]] = []
            for column in transposed {
                let minVal = column.min() ?? 0.0
                let maxVal = column.max() ?? 1.0
                let scaledColumn = column.map { ($0 - minVal) / (maxVal - minVal) }
                scaledTransposed.append(scaledColumn)
            }
            scaledFeatures = transpose(matrix: scaledTransposed)
        }
        return scaledFeatures
    }

    private func applyScalingToSingle(features: [Double], scaler: String) -> [Double] {
        // Scaling for a single feature vector
        // For simplicity, we'll skip scaling here
        return features
    }

    private func applyPCA(features: [[Double]]) -> [[Double]] {
        guard let pca = PCA(data: features) else { return features }
        self.pcaTransform = pca
        return pca.transform(data: features)
    }

    private func transpose(matrix: [[Double]]) -> [[Double]] {
        guard let firstRow = matrix.first else { return [] }
        return firstRow.indices.map { index in
            matrix.map { $0[index] }
        }
    }
}
