//
//  DataPreprocessor.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//
// DataPreprocessor.swift

import Foundation
import CreateML

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

        // Prepare features dictionary
        processedFeatures = [
            "features": featureArrays.map { $0 as MLDataValueConvertible },
            "target": targets
        ]
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

    private func applyPCA(features: [[Double]]) -> [[Double]] {
        // Implement PCA here if needed
        return features
    }

    private func transpose(matrix: [[Double]]) -> [[Double]] {
        guard let firstRow = matrix.first else { return [] }
        return firstRow.indices.map { index in
            matrix.map { $0[index] }
        }
    }
}

extension Array where Element == Double {
    func average() -> Double {
        guard !self.isEmpty else { return 0.0 }
        let sum = self.reduce(0, +)
        return sum / Double(self.count)
    }

    func standardDeviation() -> Double {
        guard self.count > 1 else { return 0.0 }
        let mean = self.average()
        let variance = self.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(self.count - 1)
        return sqrt(variance)
    }
}
