//
//  BasicKalmanFilter.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/4/24.
//


import Foundation

class BasicKalmanFilter {
    private var x: Double = 0.0 // Estimated speed
    private var P: Double = 1.0 // Estimate error covariance
    private let Q: Double = 0.1 // Process noise covariance
    private let R: Double = 4.0 // Measurement noise covariance

    func predict(acceleration: Double, deltaTime: Double) {
        // State prediction
        x += acceleration * deltaTime
        // Covariance prediction
        P += Q
    }

    func updateWithGPS(speedMeasurement: Double) {
        // Kalman gain
        let K = P / (P + R)
        // State update
        x += K * (speedMeasurement - x)
        // Covariance update
        P *= (1 - K)
    }

    func reset() {
        x = 0.0
        P = 1.0
    }

    var estimatedSpeed: Double {
        return x
    }
}
