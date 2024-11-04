//
//  CustomDynamicKalmanFilter.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/4/24.
//


import Foundation

class CustomDynamicKalmanFilter {
    private var x: Double = 0.0 // Estimated speed
    private var P: Double = 1.0 // Estimate error covariance
    private var Q: Double // Process noise covariance
    private var R: Double // Measurement noise covariance
    private var lastGPSUpdateTime: TimeInterval?

    init(processNoise: Double, measurementNoise: Double) {
        self.Q = processNoise
        self.R = measurementNoise
    }

    func predict(acceleration: Double, deltaTime: Double) {
        // State prediction
        x += acceleration * deltaTime
        // Covariance prediction
        P += Q
    }

    func updateWithGPS(speedMeasurement: Double, gpsAccuracy: Double, gpsAccuracyThreshold: Double) {
        // Adjust measurement noise based on GPS accuracy
        let adjustedR = gpsAccuracy <= gpsAccuracyThreshold ? R : R * 10 // Increase R when GPS accuracy is low

        // Kalman gain
        let K = P / (P + adjustedR)
        // State update
        x += K * (speedMeasurement - x)
        // Covariance update
        P *= (1 - K)

        // Update last GPS update time
        lastGPSUpdateTime = Date().timeIntervalSince1970
    }

    var estimatedSpeed: Double {
        return x
    }
}
