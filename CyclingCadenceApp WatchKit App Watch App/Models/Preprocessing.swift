//
//  Preprocessing.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 10/31/24.
//


// Preprocessing.swift

import Foundation
import CoreMotion

struct Preprocessing {
    static func computeFeatures(from data: [CMAccelerometerData], config: ModelConfig.Config) -> [Double] {
        var features: [Double] = []

        // Extract accelerometer data
        let accelX = data.map { $0.acceleration.x }
        let accelY = data.map { $0.acceleration.y }
        let accelZ = data.map { $0.acceleration.z }

        // Statistical features
        features.append(contentsOf: computeStatisticalFeatures(accelX))
        features.append(contentsOf: computeStatisticalFeatures(accelY))
        features.append(contentsOf: computeStatisticalFeatures(accelZ))

        // FFT features
        if config.includeFFT {
            features.append(contentsOf: computeFFTFeatures(accelX))
            features.append(contentsOf: computeFFTFeatures(accelY))
            features.append(contentsOf: computeFFTFeatures(accelZ))
        }

        // Wavelet features (if implemented)
        if config.includeWavelet {
            // Add wavelet feature extraction here
        }

        // Add other preprocessing steps as needed

        return features
    }

    static func computeStatisticalFeatures(_ data: [Double]) -> [Double] {
        let mean = data.reduce(0, +) / Double(data.count)
        let variance = data.map { pow($0 - mean, 2) }.reduce(0, +) / Double(data.count)
        let stdDev = sqrt(variance)
        return [mean, stdDev]
    }

    static func computeFFTFeatures(_ data: [Double]) -> [Double] {
        // Implement FFT feature extraction
        // Placeholder: returning empty array
        return []
    }
    static func computeStatistics(for values: [Double]) -> [Double] {
            guard !values.isEmpty else { return [0.0, 0.0] }

            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
            let stdDev = sqrt(variance)

            return [mean, stdDev]
        }
}
