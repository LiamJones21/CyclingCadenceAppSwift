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
    // Settings
    var useAccelerometer: Bool = false
    var useGPS: Bool = true

    // Accelerometer settings
    var accelerometerTuningValue: Double = 1.0
    var accelerometerWeightingX: Double = 1.0
    var accelerometerWeightingY: Double = 1.0
    var accelerometerWeightingZ: Double = 1.0
    var useLowPassFilter: Bool = false
    var lowPassFilterAlpha: Double = 0.1

    // Kalman filter settings
    var kalmanProcessNoise: Double = 0.1
    var kalmanMeasurementNoise: Double = 0.1
    var gpsAccuracyLowerBound: Double = 5.0 // Lower bound for GPS accuracy
    var gpsAccuracyUpperBound: Double = 20.0 // Upper bound for GPS accuracy

    private var kalmanFilter: AdvancedKalmanFilter?
    private var lastUpdateTime: TimeInterval = Date().timeIntervalSince1970
    var currentSpeed: Double = 0.0
    private var isSessionActive: Bool = true

    // For low-pass filter
    private var filteredAccelX: Double = 0.0
    private var filteredAccelY: Double = 0.0
    private var filteredAccelZ: Double = 0.0

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

    // Variables to store rotation rate offset samples
    private var offsetSamplesRotationX: [Double] = []
    private var offsetSamplesRotationY: [Double] = []
    private var offsetSamplesRotationZ: [Double] = []

    // MARK: - Session Control
    func reset() {
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

    func processDeviceMotionData(_ data: CMDeviceMotion) {
        let currentTime = Date().timeIntervalSince1970
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Offset Calibration
        if !offsetsCalculated {
            if offsetSamplingStartTime == nil {
                offsetSamplingStartTime = currentTime
            }

            // Collect accelerometer samples
            offsetSamplesAccelX.append(data.userAcceleration.x)
            offsetSamplesAccelY.append(data.userAcceleration.y)
            offsetSamplesAccelZ.append(data.userAcceleration.z)

            // Collect rotation rate samples
            offsetSamplesRotationX.append(data.rotationRate.x)
            offsetSamplesRotationY.append(data.rotationRate.y)
            offsetSamplesRotationZ.append(data.rotationRate.z)

            // Calculate current average accelerometer offsets
            accelOffsetX = offsetSamplesAccelX.reduce(0, +) / Double(offsetSamplesAccelX.count)
            accelOffsetY = offsetSamplesAccelY.reduce(0, +) / Double(offsetSamplesAccelY.count)
            accelOffsetZ = offsetSamplesAccelZ.reduce(0, +) / Double(offsetSamplesAccelZ.count)

            // Calculate current average rotation rate offsets
            rotationOffsetX = offsetSamplesRotationX.reduce(0, +) / Double(offsetSamplesRotationX.count)
            rotationOffsetY = offsetSamplesRotationY.reduce(0, +) / Double(offsetSamplesRotationY.count)
            rotationOffsetZ = offsetSamplesRotationZ.reduce(0, +) / Double(offsetSamplesRotationZ.count)

            // After 2 seconds, set offsetsCalculated to true
            if currentTime - offsetSamplingStartTime! >= 2.0 {
                offsetsCalculated = true
                offsetSamplingStartTime = nil

                print("Calculated accelerometer offsets:")
                print("Accel X: \(accelOffsetX), Y: \(accelOffsetY), Z: \(accelOffsetZ)")

                print("Calculated rotation rate offsets:")
                print("Rotation X: \(rotationOffsetX), Y: \(rotationOffsetY), Z: \(rotationOffsetZ)")
            }
        }

        // Proceed with speed calculation using adjusted values
        let adjustedAccelX = data.userAcceleration.x - accelOffsetX
        let adjustedAccelY = data.userAcceleration.y - accelOffsetY
        let adjustedAccelZ = data.userAcceleration.z - accelOffsetZ

        let adjustedRotationRateX = data.rotationRate.x - rotationOffsetX
        let adjustedRotationRateY = data.rotationRate.y - rotationOffsetY
        let adjustedRotationRateZ = data.rotationRate.z - rotationOffsetZ

        // Apply low-pass filter if enabled
        var accelX = adjustedAccelX
        var accelY = adjustedAccelY
        var accelZ = adjustedAccelZ

        if useLowPassFilter {
            filteredAccelX = lowPassFilterAlpha * adjustedAccelX + (1 - lowPassFilterAlpha) * filteredAccelX
            filteredAccelY = lowPassFilterAlpha * adjustedAccelY + (1 - lowPassFilterAlpha) * filteredAccelY
            filteredAccelZ = lowPassFilterAlpha * adjustedAccelZ + (1 - lowPassFilterAlpha) * filteredAccelZ

            accelX = filteredAccelX
            accelY = filteredAccelY
            accelZ = filteredAccelZ
        }

        // Apply direction weightings
        accelX *= accelerometerWeightingX
        accelY *= accelerometerWeightingY
        accelZ *= accelerometerWeightingZ

        // Accelerometer-only speed calculation
        if useAccelerometer && !useGPS {
            let acceleration = sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ)
            let accelerationThreshold = 0.01 // Threshold to filter out noise
            let netAcceleration = acceleration > accelerationThreshold ? acceleration : 0.0

            currentSpeed += netAcceleration * deltaTime * accelerometerTuningValue

            // Correct for negative speed
            if currentSpeed < 0 {
                currentSpeed = 0
            }
        }
        // GPS and Accelerometer combined
        else if useAccelerometer && useGPS {
            if kalmanFilter == nil {
                kalmanFilter = AdvancedKalmanFilter()
            }

            let acceleration = sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ)
            kalmanFilter?.processNoise = kalmanProcessNoise
            kalmanFilter?.measurementNoise = kalmanMeasurementNoise
            kalmanFilter?.gpsAccuracyLowerBound = gpsAccuracyLowerBound
            kalmanFilter?.gpsAccuracyUpperBound = gpsAccuracyUpperBound

            kalmanFilter?.predict(acceleration: acceleration, deltaTime: deltaTime)
            if let estimatedSpeed = kalmanFilter?.estimatedSpeed {
                currentSpeed = max(0, estimatedSpeed)
            }
        }
    }

    func processLocationData(_ location: CLLocation) {
        guard useGPS else { return }

        let gpsSpeed = max(location.speed, 0)
        if useAccelerometer && useGPS {
            if let kalmanFilter = kalmanFilter {
                kalmanFilter.updateWithGPS(speedMeasurement: gpsSpeed, gpsAccuracy: location.horizontalAccuracy)
                currentSpeed = max(0, kalmanFilter.estimatedSpeed)
            }
        } else if useGPS && !useAccelerometer {
            currentSpeed = gpsSpeed
        }
    }
}
