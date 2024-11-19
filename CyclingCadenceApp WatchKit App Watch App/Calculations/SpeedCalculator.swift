//
//
//
//  SpeedCalculator.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/3/24.

import Foundation
import CoreMotion
import CoreLocation

class SpeedCalculator {
    // Settings
    var useAccelerometer: Bool = true
    var useGPS: Bool = true

    // Accelerometer settings
    var accelerometerTuningValue: Double = 1.0
    var accelerometerWeightingX: Double = 1.0
    var accelerometerWeightingY: Double = 1.0
    var accelerometerWeightingZ: Double = 1.0
    var useLowPassFilter: Bool = false
    var lowPassFilterAlpha: Double = 0.1

    // Kalman filter settings
    var baseProcessNoise: Double = 0.1
    var baseMeasurementNoise: Double = 0.1

    // Adaptive friction settings
    private var accelerationHistory: [Double] = []
    private let accelerationHistorySize = 20 // Number of samples to consider

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

    public var GPSSpeedEstimate: Double = 0.0
    public var GPSSpeedEstimateAccuracy: Double = 0.0
    
    public var kalmanProcessNoise: Double = 0.1
    public var kalmanMeasurementNoise: Double = 0.1
    
    private var previousVelocityX: Double = 0.0
    private var previousVelocityY: Double = 0.0
    private var previousVelocityZ: Double = 0.0
    

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
        accelerationHistory.removeAll()
    }

    func stopSession() {
        isSessionActive = false
    }

//    func processDeviceMotionData(_ data: CMDeviceMotion) {
//        let currentTime = Date().timeIntervalSince1970
//        var deltaTime = currentTime - lastUpdateTime
//        // Ensure deltaTime is reasonable
//        if deltaTime <= 0 || deltaTime > 1 {
//            deltaTime = 0.01 // Assign a default value if deltaTime is invalid
//        }
//        lastUpdateTime = currentTime
//
//        // Offset Calibration
//        if !offsetsCalculated {
//            if offsetSamplingStartTime == nil {
//                offsetSamplingStartTime = currentTime
//            }
//
//            // Collect accelerometer samples
//            offsetSamplesAccelX.append(data.userAcceleration.x)
//            offsetSamplesAccelY.append(data.userAcceleration.y)
//            offsetSamplesAccelZ.append(data.userAcceleration.z)
//
//            // Collect rotation rate samples
//            offsetSamplesRotationX.append(data.rotationRate.x)
//            offsetSamplesRotationY.append(data.rotationRate.y)
//            offsetSamplesRotationZ.append(data.rotationRate.z)
//
//            // Calculate current average accelerometer offsets
//            accelOffsetX = offsetSamplesAccelX.reduce(0, +) / Double(offsetSamplesAccelX.count)
//            accelOffsetY = offsetSamplesAccelY.reduce(0, +) / Double(offsetSamplesAccelY.count)
//            accelOffsetZ = offsetSamplesAccelZ.reduce(0, +) / Double(offsetSamplesAccelZ.count)
//
//            // Calculate current average rotation rate offsets
//            rotationOffsetX = offsetSamplesRotationX.reduce(0, +) / Double(offsetSamplesRotationX.count)
//            rotationOffsetY = offsetSamplesRotationY.reduce(0, +) / Double(offsetSamplesRotationY.count)
//            rotationOffsetZ = offsetSamplesRotationZ.reduce(0, +) / Double(offsetSamplesRotationZ.count)
//
//            // After 2 seconds, set offsetsCalculated to true
//            if currentTime - offsetSamplingStartTime! >= 2.0 {
//                offsetsCalculated = true
//                offsetSamplingStartTime = nil
//
//                print("Calculated accelerometer offsets:")
//                print("Accel X: \(accelOffsetX), Y: \(accelOffsetY), Z: \(accelOffsetZ)")
//
//                print("Calculated rotation rate offsets:")
//                print("Rotation X: \(rotationOffsetX), Y: \(rotationOffsetY), Z: \(rotationOffsetZ)")
//            }
//        }
//
//        // Proceed with speed calculation using adjusted values
//        let adjustedAccelX = data.userAcceleration.x - accelOffsetX
//        let adjustedAccelY = data.userAcceleration.y - accelOffsetY
//        let adjustedAccelZ = data.userAcceleration.z - accelOffsetZ
//
//        // Adjusted rotation rates (accessible for other scripts)
//        let adjustedRotationRateX = data.rotationRate.x - rotationOffsetX
//        let adjustedRotationRateY = data.rotationRate.y - rotationOffsetY
//        let adjustedRotationRateZ = data.rotationRate.z - rotationOffsetZ
//
//        // Apply low-pass filter if enabled
//        var accelX = adjustedAccelX
//        var accelY = adjustedAccelY
//        var accelZ = adjustedAccelZ
//
//        if useLowPassFilter {
//            filteredAccelX = lowPassFilterAlpha * adjustedAccelX + (1 - lowPassFilterAlpha) * filteredAccelX
//            filteredAccelY = lowPassFilterAlpha * adjustedAccelY + (1 - lowPassFilterAlpha) * filteredAccelY
//            filteredAccelZ = lowPassFilterAlpha * adjustedAccelZ + (1 - lowPassFilterAlpha) * filteredAccelZ
//
//            accelX = filteredAccelX
//            accelY = filteredAccelY
//            accelZ = filteredAccelZ
//        }
//
//        // Apply direction weightings
//        accelX *= accelerometerWeightingX
//        accelY *= accelerometerWeightingY
//        accelZ *= accelerometerWeightingZ
//
//        // Compute the magnitude of acceleration
//        let accelerationMagnitude = sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ)
//
//        // Update acceleration history
//        accelerationHistory.append(accelerationMagnitude)
//        if accelerationHistory.count > accelerationHistorySize {
//            accelerationHistory.removeFirst()
//        }
//
//        // Calculate variance over the time window
//        let accelerationVariance = variance(of: accelerationHistory)
//
//        // Initialize Kalman Filter if necessary
//        if kalmanFilter == nil {
//            kalmanFilter = AdvancedKalmanFilter()
//        }
//
//        // Predict step with adaptive friction
//        kalmanFilter?.processNoise = kalmanProcessNoise
//        kalmanFilter?.predict(acceleration: accelerationMagnitude, deltaTime: deltaTime, accelerationVariance: accelerationVariance)
//
//        // Update current speed estimate
//        if let estimatedSpeed = kalmanFilter?.estimatedSpeed {
//            currentSpeed = max(0, estimatedSpeed)
//        }
//    }
    // Add these variables to track estimated velocity
//    private var estimatedVelocityX: Double = 0.0
//    private var estimatedVelocityY: Double = 0.0
//    private var estimatedVelocityZ: Double = 0.0
//
//    func processDeviceMotionData(_ data: CMDeviceMotion) {
//        let currentTime = Date().timeIntervalSince1970
//        var deltaTime = currentTime - lastUpdateTime
//        // Ensure deltaTime is reasonable
//        if deltaTime <= 0 || deltaTime > 1 {
//            deltaTime = 0.01 // Assign a default value if deltaTime is invalid
//        }
//        lastUpdateTime = currentTime
//
//        // Offset Calibration
//        if !offsetsCalculated {
//            if offsetSamplingStartTime == nil {
//                offsetSamplingStartTime = currentTime
//            }
//
//            // Collect accelerometer samples
//            offsetSamplesAccelX.append(data.userAcceleration.x)
//            offsetSamplesAccelY.append(data.userAcceleration.y)
//            offsetSamplesAccelZ.append(data.userAcceleration.z)
//
//            // Collect rotation rate samples
//            offsetSamplesRotationX.append(data.rotationRate.x)
//            offsetSamplesRotationY.append(data.rotationRate.y)
//            offsetSamplesRotationZ.append(data.rotationRate.z)
//
//            // Calculate current average accelerometer offsets
//            accelOffsetX = offsetSamplesAccelX.reduce(0, +) / Double(offsetSamplesAccelX.count)
//            accelOffsetY = offsetSamplesAccelY.reduce(0, +) / Double(offsetSamplesAccelY.count)
//            accelOffsetZ = offsetSamplesAccelZ.reduce(0, +) / Double(offsetSamplesAccelZ.count)
//
//            // Calculate current average rotation rate offsets
//            rotationOffsetX = offsetSamplesRotationX.reduce(0, +) / Double(offsetSamplesRotationX.count)
//            rotationOffsetY = offsetSamplesRotationY.reduce(0, +) / Double(offsetSamplesRotationY.count)
//            rotationOffsetZ = offsetSamplesRotationZ.reduce(0, +) / Double(offsetSamplesRotationZ.count)
//
//            // After 2 seconds, set offsetsCalculated to true
//            if currentTime - offsetSamplingStartTime! >= 2.0 {
//                offsetsCalculated = true
//                offsetSamplingStartTime = nil
//
//                print("Calculated accelerometer offsets:")
//                print("Accel X: \(accelOffsetX), Y: \(accelOffsetY), Z: \(accelOffsetZ)")
//
//                print("Calculated rotation rate offsets:")
//                print("Rotation X: \(rotationOffsetX), Y: \(rotationOffsetY), Z: \(rotationOffsetZ)")
//            }
//        }
//
//        // Proceed with speed calculation using adjusted values
//        let adjustedAccelX = data.userAcceleration.x - accelOffsetX
//        let adjustedAccelY = data.userAcceleration.y - accelOffsetY
//        let adjustedAccelZ = data.userAcceleration.z - accelOffsetZ
//
//        // Adjusted rotation rates (accessible for other scripts)
//        let adjustedRotationRateX = data.rotationRate.x - rotationOffsetX
//        let adjustedRotationRateY = data.rotationRate.y - rotationOffsetY
//        let adjustedRotationRateZ = data.rotationRate.z - rotationOffsetZ
//
//        // Apply low-pass filter if enabled
//        var accelX = adjustedAccelX
//        var accelY = adjustedAccelY
//        var accelZ = adjustedAccelZ
//
//        if useLowPassFilter {
//            filteredAccelX = lowPassFilterAlpha * adjustedAccelX + (1 - lowPassFilterAlpha) * filteredAccelX
//            filteredAccelY = lowPassFilterAlpha * adjustedAccelY + (1 - lowPassFilterAlpha) * filteredAccelY
//            filteredAccelZ = lowPassFilterAlpha * adjustedAccelZ + (1 - lowPassFilterAlpha) * filteredAccelZ
//
//            accelX = filteredAccelX
//            accelY = filteredAccelY
//            accelZ = filteredAccelZ
//        }
//
//        // Apply direction weightings
//        accelX *= accelerometerWeightingX
//        accelY *= accelerometerWeightingY
//        accelZ *= accelerometerWeightingZ
//
//        // Compute the magnitude of acceleration
//        let accelerationMagnitude = sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ)
//
//        // Update acceleration history
//        accelerationHistory.append(accelerationMagnitude)
//        if accelerationHistory.count > accelerationHistorySize {
//            accelerationHistory.removeFirst()
//        }
//
//        // Calculate variance over the time window
//        let accelerationVariance = variance(of: accelerationHistory)
//
//        // Compute adaptive friction
//        let minFriction = 0.05
//        let maxFriction = 0.3
//        let k = 5.0
//        let frictionCoefficient = minFriction + (maxFriction - minFriction) * (1 - exp(-k * accelerationVariance))
//        let friction = -frictionCoefficient * currentSpeed
//
//        // Compute net acceleration with friction
//        let netAcceleration = accelerationMagnitude + friction
//
//        // Update speed using Kalman Filter
//        if kalmanFilter == nil {
//            kalmanFilter = AdvancedKalmanFilter()
//        }
//        kalmanFilter?.processNoise = kalmanProcessNoise
//        kalmanFilter?.predict(acceleration: netAcceleration, deltaTime: deltaTime)
//
//        // Update current speed estimate
//        if let estimatedSpeed = kalmanFilter?.estimatedSpeed {
//            currentSpeed = max(0.0, estimatedSpeed)
//        }
//    }
    private var estimatedVelocityX: Double = 0.0
    private var estimatedVelocityY: Double = 0.0
    private var estimatedVelocityZ: Double = 0.0

    func processDeviceMotionData(_ data: CMDeviceMotion) {
        let currentTime = Date().timeIntervalSince1970
        var deltaTime = currentTime - lastUpdateTime
        // Ensure deltaTime is reasonable
        if deltaTime <= 0 || deltaTime > 1 {
            deltaTime = 0.01 // Assign a default value if deltaTime is invalid
        }
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
        
        // Adjusted rotation rates (accessible for other scripts)
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
        
        
        // Update acceleration history (magnitude not used here)
        accelerationHistory.append(accelX)
        if accelerationHistory.count > accelerationHistorySize {
            accelerationHistory.removeFirst()
        }
        
        // Calculate variance over the time window (optional)
        let accelerationVariance = variance(of: accelerationHistory)
        
        // Compute signed acceleration (along Y-axis)
        let signedAcceleration = accelX
        
        // Adaptive friction (adjusted to ensure speed decreases when stopping)
        let frictionCoefficient = 0.2 // Adjust as needed
        let friction = -frictionCoefficient * currentSpeed
        
        // Update speed with signed acceleration and friction
        currentSpeed += (signedAcceleration + friction) * deltaTime
        currentSpeed = max(0.0, currentSpeed) // Ensure speed doesn't go below zero
        
        // Initialize Kalman Filter if necessary
        if kalmanFilter == nil {
            kalmanFilter = AdvancedKalmanFilter()
        }
        
        // Predict step without friction (since friction is already applied)
        kalmanFilter?.processNoise = kalmanProcessNoise
        kalmanFilter?.predict(acceleration: signedAcceleration, deltaTime: deltaTime)
        
        // Update current speed estimate
        if let estimatedSpeed = kalmanFilter?.estimatedSpeed {
            currentSpeed = max(0.0, estimatedSpeed)
        }
    }
    
    
    func processLocationData(_ location: CLLocation) {
        guard useGPS else { return }

        GPSSpeedEstimate = location.speed
        GPSSpeedEstimateAccuracy = location.horizontalAccuracy

        let gpsSpeed = max(location.speed, 0)

        // Compute dynamic measurement noise based on GPS accuracy and speed
        let gpsAccuracy = location.horizontalAccuracy
        let speedFactor = gpsSpeed / 10.0 // Adjust denominator based on typical speeds

        // Weighting factors (higher weighting means more trust)
        let accuracyWeighting = min(1.0, 5.0 / gpsAccuracy) // Trust GPS more when accuracy is less than 5 meters
        let speedWeighting = min(1.0, speedFactor) // Trust GPS more at higher speeds

        let dynamicMeasurementNoise = kalmanMeasurementNoise / (accuracyWeighting * speedWeighting + 0.01) // Avoid division by zero

        // Update Kalman Filter
        if kalmanFilter == nil {
            kalmanFilter = AdvancedKalmanFilter()
        }

        kalmanFilter?.measurementNoise = dynamicMeasurementNoise
        kalmanFilter?.updateWithGPS(speedMeasurement: gpsSpeed)

        // Update current speed estimate
        if let estimatedSpeed = kalmanFilter?.estimatedSpeed {
            currentSpeed = max(0, estimatedSpeed)
        }
    }

    // Helper function to calculate variance
    private func variance(of data: [Double]) -> Double {
        let mean = data.reduce(0, +) / Double(data.count)
        let squaredDifferences = data.map { ($0 - mean) * ($0 - mean) }
        return squaredDifferences.reduce(0, +) / Double(data.count)
    }
}

func normalizeVector(_ vector: [Double]) -> [Double] {
    let magnitude = sqrt(vector.map { $0 * $0 }.reduce(0, +))
    return magnitude > 0 ? vector.map { $0 / magnitude } : vector
}

func dotProduct(_ vectorA: [Double], _ vectorB: [Double]) -> Double {
    return zip(vectorA, vectorB).map(*).reduce(0, +)
}
private func variance(of data: [Double]) -> Double {
    let mean = data.reduce(0, +) / Double(data.count)
    let squaredDifferences = data.map { ($0 - mean) * ($0 - mean) }
    return squaredDifferences.reduce(0, +) / Double(data.count)
}
