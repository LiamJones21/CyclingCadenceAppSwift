//
//  KalmanFilter.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/1/24.
//
// AdvancedKalmanFilter.swift

import Foundation

class AdvancedKalmanFilter {
    private var x: Double = 0.0 // Estimated speed
    private var P: Double = 1.0 // Estimate error covariance
    var processNoise: Double = 0.1 // Process noise covariance (Q)
    var measurementNoise: Double = 0.1 // Base measurement noise covariance (R)
    var gpsAccuracyLowerBound: Double = 5.0 // Lower bound
    var gpsAccuracyUpperBound: Double = 20.0 // Upper bound

    private var lastGPSUpdateTime: TimeInterval?

    func predict(acceleration: Double, deltaTime: Double) {
        x += acceleration * deltaTime
        P += processNoise

        // Increase process noise over time if no GPS update
        if let lastGPSUpdateTime = lastGPSUpdateTime {
            let timeSinceLastGPS = Date().timeIntervalSince1970 - lastGPSUpdateTime
            if timeSinceLastGPS > 1.0 {
                processNoise = min(processNoise + 0.01, 10.0)
            }
        } else {
            processNoise = min(processNoise + 0.01, 10.0)
        }
    }

    func updateWithGPS(speedMeasurement: Double, gpsAccuracy: Double) {
        // Calculate weighting based on GPS accuracy
        let weighting: Double
        if gpsAccuracy <= gpsAccuracyLowerBound {
            weighting = 1.0 // Fully trust GPS
        } else if gpsAccuracy >= gpsAccuracyUpperBound {
            weighting = 0.0 // Ignore GPS
        } else {
            weighting = 1.0 - (gpsAccuracy - gpsAccuracyLowerBound) / (gpsAccuracyUpperBound - gpsAccuracyLowerBound)
        }

        // Adjust measurement noise R
        let R: Double
        if weighting > 0 {
            R = measurementNoise / weighting
        } else {
            R = Double.greatestFiniteMagnitude // Effectively ignore GPS
        }

        // Kalman gain
        let K = P / (P + R)
        // State update
        x += K * (speedMeasurement - x)
        // Covariance update
        P *= (1 - K)

        // Reset process noise if GPS is reliable
        if gpsAccuracy <= gpsAccuracyLowerBound {
            processNoise = 0.1
        }

        // Update last GPS update time
        lastGPSUpdateTime = Date().timeIntervalSince1970
    }

    func reset() {
        x = 0.0
        P = 1.0
        processNoise = 0.1
        lastGPSUpdateTime = nil
    }

    var estimatedSpeed: Double {
        return x
    }
}
