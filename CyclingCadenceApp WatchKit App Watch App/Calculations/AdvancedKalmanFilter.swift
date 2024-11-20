//
//
//
//  AdvancedKalmanFilter.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/1/24.

import Foundation

class AdvancedKalmanFilter {
    private var x: Double // Estimated speed
    private var P: Double // Estimate error covariance
    private var Q: Double // Process noise covariance
    private var R: Double // Measurement noise covariance

    private let accelerometerNoise: Double
    private let gpsBaseNoise: Double

    private var lastGPSUpdateTime: TimeInterval?
    private var lastGPSSpeed: Double = 0.0

    init(initialSpeed: Double = 0.0, processNoise: Double = 0.1, accelerometerNoise: Double = 0.5, gpsBaseNoise: Double = 1.0) {
        self.x = initialSpeed
        self.P = 1.0
        self.Q = processNoise
        self.accelerometerNoise = accelerometerNoise
        self.gpsBaseNoise = gpsBaseNoise
        self.R = accelerometerNoise // Initial measurement noise covariance is set to accelerometer noise
    }

    // Predict step using accelerometer data
    func predict(acceleration: Double, deltaTime: Double) {
        // State prediction
        x += acceleration * deltaTime
        // Covariance prediction
        P += Q

        // If no recent GPS update, gradually increase process noise to rely less on acceleration
        if let lastGPSUpdateTime = lastGPSUpdateTime {
            let timeSinceLastGPS = Date().timeIntervalSince1970 - lastGPSUpdateTime
            if timeSinceLastGPS > 1.0 {
                Q += 0.01 // Gradually increase process noise
            }
        } else {
            // No GPS data received yet
            Q += 0.01
        }
    }

    // Update step using GPS speed measurement
    func updateWithGPS(speedMeasurement: Double, gpsAccuracy: Double) {
        // Adjust measurement noise covariance based on GPS accuracy
        let adjustedGpsNoise = gpsBaseNoise * (gpsAccuracy / 5.0)

        // Limit adjustedGpsNoise to reasonable values
        let maxGpsNoise = 100.0
        let minGpsNoise = 1.0
        let gpsNoise = min(max(adjustedGpsNoise, minGpsNoise), maxGpsNoise)

        R = gpsNoise

        // Kalman gain
        let K = P / (P + R)
        // State update
        x = x + K * (speedMeasurement - x)
        // Covariance update
        P = (1 - K) * P

        // Reset process noise when GPS data is reliable
        if gpsAccuracy < 10.0 {
            Q = 0.1 // Reset to default
        }

        // Store last GPS update time and speed
        lastGPSUpdateTime = Date().timeIntervalSince1970
        lastGPSSpeed = speedMeasurement
    }

    func resetSpeed() {
        x = 0.0
        P = 1.0
        lastGPSUpdateTime = nil
        lastGPSSpeed = 0.0
    }

    var estimatedSpeed: Double {
        return x
    }
}
