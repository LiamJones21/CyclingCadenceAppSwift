//
//
//
//  AdvancedKalmanFilter.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/1/24.

import Foundation

class AdvancedKalmanFilter {
    private var x: Double = 0.0 // Estimated speed
    private var P: Double = 1.0 // Estimate error covariance
    var processNoise: Double = 0.1 // Base process noise covariance (Q)
    var measurementNoise: Double = 0.1 // Measurement noise covariance (R)

//    func predict(acceleration: Double, deltaTime: Double, accelerationVariance: Double) {
//        // Adaptive friction coefficient based on acceleration variance
//        let minFriction = 0.1   // Minimum friction when variance is high (device is moving)
//        let maxFriction = 0.5   // Maximum friction when variance is low (device is stationary)
//        let k = 1.0             // Tuning parameter for sensitivity
//
//        // Compute friction coefficient using an inverse relationship
//        // Friction increases when variance decreases, and vice versa
//        let frictionCoefficient = minFriction + (maxFriction - minFriction) * exp(-k * accelerationVariance)
//
//        // Ensure friction coefficient is always greater than zero
//        let friction = -frictionCoefficient * x
//
//        // Predict the next state
//        x += (acceleration + friction) * deltaTime
//        P += processNoise
//
//        // Ensure speed is not negative
//        x = max(0.0, x)
//    }
    func predict(acceleration: Double, deltaTime: Double) {
            x += acceleration * deltaTime
            P += processNoise

            // Ensure speed remains non-negative
            x = max(0.0, x)
        }

    func updateWithGPS(speedMeasurement: Double) {
        // Kalman gain
        let K = P / (P + measurementNoise)

        // Update estimate with measurement
        x += K * (speedMeasurement - x)

        // Update error covariance
        P *= (1 - K)

        // Ensure speed is not negative
        x = max(0.0, x)
    }

    var estimatedSpeed: Double {
        return x
    }
}
