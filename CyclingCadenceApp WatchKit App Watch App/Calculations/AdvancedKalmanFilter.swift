//
//  KalmanFilter.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/1/24.
//


import Foundation

// MARK: - SpeedKalmanFilter Class
class AdvancedKalmanFilter {
    private var x: Double // Estimated speed
    private var P: Double // Estimate error covariance
    private let Q: Double // Process noise covariance
    private let R: Double // Measurement noise covariance

    init(initialSpeed: Double = 0.0, initialErrorCovariance: Double = 1.0, processNoise: Double = 1e-1, measurementNoise: Double = 1e-0) {
        self.x = initialSpeed
        self.P = initialErrorCovariance
        self.Q = processNoise
        self.R = measurementNoise
    }

    func predict(acceleration: Double, deltaTime: Double) {
        // State prediction
        x += acceleration * deltaTime
        // Covariance prediction
        P += Q
    }

    func update(measurement: Double) {
        // Kalman gain
        let K = P / (P + R)
        // State update
        x = x + K * (measurement - x)
        // Covariance update
        P = (1 - K) * P
    }

    func resetSpeed() {
        x = 0.0
        P = 1.0
    }

    var estimatedSpeed: Double {
        return x
    }
}
