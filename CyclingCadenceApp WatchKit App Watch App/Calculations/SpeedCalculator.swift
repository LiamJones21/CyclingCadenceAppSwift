//
//  SpeedCalculator.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/3/24.
// SpeedCalculator.swift

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

    // Variables to store rotation rate offsets
    public var rotationOffsetX: Double = 0.0
    public var rotationOffsetY: Double = 0.0
    public var rotationOffsetZ: Double = 0.0

    private var offsetSamplingStartTime: TimeInterval?
    private var offsetsCalculated = false

    private var offsetSamplesAccelX: [Double] = []
    private var offsetSamplesAccelY: [Double] = []
    private var offsetSamplesAccelZ: [Double] = []

    private var offsetSamplesRotationX: [Double] = []
    private var offsetSamplesRotationY: [Double] = []
    private var offsetSamplesRotationZ: [Double] = []

    private var lastOffsetCalculationTime: TimeInterval = 0.0
    private var isRecalculatingOffsets: Bool = false
    private var lowConfidenceStartTime: TimeInterval?
    private let lowConfidenceDurationThreshold: TimeInterval = 5.0 // Adjust as needed

    // MARK: - Session Control
    func reset() {
        kalmanFilter.resetSpeed()
        currentSpeed = 0.0
        lastUpdateTime = Date().timeIntervalSince1970
        isSessionActive = true

        // Reset offsets
        accelOffsetX = 0.0
        accelOffsetY = 0.0
        accelOffsetZ = 0.0
        rotationOffsetX = 0.0
        rotationOffsetY = 0.0
        rotationOffsetZ = 0.0
        offsetsCalculated = false
        lastOffsetCalculationTime = 0.0
        isRecalculatingOffsets = false
        offsetSamplingStartTime = nil

        // Clear samples
        offsetSamplesAccelX.removeAll()
        offsetSamplesAccelY.removeAll()
        offsetSamplesAccelZ.removeAll()
        offsetSamplesRotationX.removeAll()
        offsetSamplesRotationY.removeAll()
        offsetSamplesRotationZ.removeAll()
    }

    func stopSession() {
        isSessionActive = false
    }

    func resetSpeedOnly() {
        kalmanFilter.resetSpeed()
        currentSpeed = 0.0
        lastUpdateTime = Date().timeIntervalSince1970
    }

    func processDeviceMotionData(_ data: CMDeviceMotion) {
        let currentTime = Date().timeIntervalSince1970
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Check if we need to recalculate offsets
        if !offsetsCalculated || (currentTime - lastOffsetCalculationTime >= 10.0 && !isRecalculatingOffsets) {
            // Start recalculating offsets
            isRecalculatingOffsets = true
            offsetSamplingStartTime = currentTime

            // Clear previous samples
            offsetSamplesAccelX.removeAll()
            offsetSamplesAccelY.removeAll()
            offsetSamplesAccelZ.removeAll()
            offsetSamplesRotationX.removeAll()
            offsetSamplesRotationY.removeAll()
            offsetSamplesRotationZ.removeAll()
        }

        if isRecalculatingOffsets {
            // Collect samples
            offsetSamplesAccelX.append(data.userAcceleration.x)
            offsetSamplesAccelY.append(data.userAcceleration.y)
            offsetSamplesAccelZ.append(data.userAcceleration.z)

            offsetSamplesRotationX.append(data.rotationRate.x)
            offsetSamplesRotationY.append(data.rotationRate.y)
            offsetSamplesRotationZ.append(data.rotationRate.z)

            // Collect samples over 2 seconds
            if currentTime - offsetSamplingStartTime! >= 2.0 {
                // Calculate average offsets
                accelOffsetX = offsetSamplesAccelX.reduce(0, +) / Double(offsetSamplesAccelX.count)
                accelOffsetY = offsetSamplesAccelY.reduce(0, +) / Double(offsetSamplesAccelY.count)
                accelOffsetZ = offsetSamplesAccelZ.reduce(0, +) / Double(offsetSamplesAccelZ.count)

                rotationOffsetX = offsetSamplesRotationX.reduce(0, +) / Double(offsetSamplesRotationX.count)
                rotationOffsetY = offsetSamplesRotationY.reduce(0, +) / Double(offsetSamplesRotationY.count)
                rotationOffsetZ = offsetSamplesRotationZ.reduce(0, +) / Double(offsetSamplesRotationZ.count)

                offsetsCalculated = true
                lastOffsetCalculationTime = currentTime
                isRecalculatingOffsets = false
                offsetSamplingStartTime = nil

                print("Recalculated offsets at \(currentTime):")
                print("Accel X: \(accelOffsetX), Y: \(accelOffsetY), Z: \(accelOffsetZ)")
                print("Rotation X: \(rotationOffsetX), Y: \(rotationOffsetY), Z: \(rotationOffsetZ)")
            } else {
                // Not enough samples yet, return
                return
            }
        }

        // Proceed with speed calculation using adjusted values
        let adjustedAccelX = data.userAcceleration.x - accelOffsetX
        let adjustedAccelY = data.userAcceleration.y - accelOffsetY
        let adjustedAccelZ = data.userAcceleration.z - accelOffsetZ

        let totalAcceleration = sqrt(pow(adjustedAccelX, 2) + pow(adjustedAccelY, 2) + pow(adjustedAccelZ, 2))

        // Dynamic damping based on movement confidence
        let movementConfidence = min(max(totalAcceleration / 1.0, 0.0), 1.0)
        let dampingFactor = 1.0 - (1.0 - movementConfidence) * 0.1

        // Apply damping to speed estimate
        currentSpeed *= dampingFactor

        // Implement movement reset logic over a longer period
        if movementConfidence < 0.05 {
            if lowConfidenceStartTime == nil {
                lowConfidenceStartTime = currentTime
            } else if currentTime - lowConfidenceStartTime! >= lowConfidenceDurationThreshold {
                // Low confidence for threshold duration, reset speed
                resetSpeedOnly()
                lowConfidenceStartTime = nil
            }
        } else {
            lowConfidenceStartTime = nil
        }
    }

    func processLocationData(_ location: CLLocation) {
        // Update with GPS speed if available
        if location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 100 {
            let gpsSpeed = max(location.speed, 0)
            kalmanFilter.updateWithGPS(speedMeasurement: gpsSpeed, gpsAccuracy: location.horizontalAccuracy)
            currentSpeed = max(0, kalmanFilter.estimatedSpeed)
        }
    }
}
