//
//  SpeedCalculator.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/3/24.
// SpeedCalculator.swift
// CyclingCadenceApp

import Foundation
import CoreMotion
import CoreLocation

class SpeedCalculator {
    private var kalmanFilter = AdvancedKalmanFilter()
    private var lastUpdateTime: TimeInterval = Date().timeIntervalSince1970
    var currentSpeed: Double = 0.0
    private var isSessionActive: Bool = false

    // Variables to store accelerometer offsets
    public var accelOffsetX: Double = 0.0
    public var accelOffsetY: Double = 0.0
    public var accelOffsetZ: Double = 0.0

    func reset() {
        kalmanFilter.resetSpeed()
        lastUpdateTime = Date().timeIntervalSince1970
        accelOffsetX = 0.0
        accelOffsetY = 0.0
        accelOffsetZ = 0.0
        isSessionActive = true
    }

    func stopSession() {
        isSessionActive = false
    }

    func processAccelerometerData(_ data: CMAccelerometerData) {
        let currentTime = Date().timeIntervalSince1970
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // On session start, set the accelerometer offsets
        if isSessionActive && accelOffsetX == 0.0 && accelOffsetY == 0.0 && accelOffsetZ == 0.0 {
            accelOffsetX = data.acceleration.x
            accelOffsetY = data.acceleration.y
            accelOffsetZ = data.acceleration.z
        }

        // Adjust for offsets
        let accelerationX = data.acceleration.x - accelOffsetX
        let accelerationY = data.acceleration.y - accelOffsetY
        let accelerationZ = data.acceleration.z - accelOffsetZ

        // Prioritize X-axis acceleration
        let acceleration = accelerationX

        // Convert to m/s^2
        let acceleration_m_s2 = acceleration * 9.81

        // Predict step of Kalman Filter
        kalmanFilter.predict(acceleration: acceleration_m_s2, deltaTime: deltaTime)

        // Update current speed
        currentSpeed = max(0, kalmanFilter.estimatedSpeed)
    }

    func processLocationData(_ location: CLLocation) {
        // Update with GPS speed if available
        if location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 100 {
            let gpsSpeed = max(location.speed, 0)
            kalmanFilter.updateWithGPS(speedMeasurement: gpsSpeed, gpsAccuracy: location.horizontalAccuracy)
            currentSpeed = max(0, kalmanFilter.estimatedSpeed)
        }
    }
    func processDeviceMotionData(_ data: CMDeviceMotion) {
        let currentTime = Date().timeIntervalSince1970
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // On session start, set the accelerometer offsets
        if isSessionActive && accelOffsetX == 0.0 && accelOffsetY == 0.0 && accelOffsetZ == 0.0 {
            accelOffsetX = data.userAcceleration.x
            accelOffsetY = data.userAcceleration.y
            accelOffsetZ = data.userAcceleration.z
        }

        // Adjust for offsets
        let accelerationX = data.userAcceleration.x - accelOffsetX
        let accelerationY = data.userAcceleration.y - accelOffsetY
        let accelerationZ = data.userAcceleration.z - accelOffsetZ

        // Calculate total acceleration magnitude
        let totalAcceleration = sqrt(pow(accelerationX, 2) + pow(accelerationY, 2) + pow(accelerationZ, 2))

        // Z-axis noise level
        let zNoiseLevel = abs(accelerationZ)

        // Dynamic speed damping based on Z-axis noise and current speed
        var dampingFactor = 1.0
        if currentSpeed < 1.0 && zNoiseLevel < 0.02 {
            // Apply stronger damping when speed is low and Z-axis activity is low
            dampingFactor = 0.9
        } else if zNoiseLevel < 0.05 {
            // Apply mild damping
            dampingFactor = 0.95
        }

        // Predict step of Kalman Filter with adjusted acceleration
        kalmanFilter.predict(acceleration: totalAcceleration * dampingFactor, deltaTime: deltaTime)

        // Update current speed
        currentSpeed = max(0, kalmanFilter.estimatedSpeed * dampingFactor)
    }
}
