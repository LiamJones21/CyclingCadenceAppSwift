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
    var gpsAccuracyThreshold: Double = 10.0

    private var kalmanFilter: CustomDynamicKalmanFilter?
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

    private var offsetSamplesRotationX: [Double] = []
    private var offsetSamplesRotationY: [Double] = []
    private var offsetSamplesRotationZ: [Double] = []

    private var lastOffsetCalculationTime: TimeInterval = 0.0
    private var isRecalculatingOffsets: Bool = false
    private var lowConfidenceStartTime: TimeInterval?
    private let lowConfidenceDurationThreshold: TimeInterval = 5.0 // Adjust as needed

    // MARK: - Session Control
    func reset() {
//        kalmanFilter.resetSpeed()
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
//        kalmanFilter.resetSpeed()
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

        if useAccelerometer && !useGPS {
            // Use accelerometer data only
            let acceleration = sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ)
            currentSpeed += acceleration * deltaTime * accelerometerTuningValue

            // Apply drift correction
            if currentSpeed < 0 {
                currentSpeed = 0
            }
        } else if useGPS && !useAccelerometer {
            // Do nothing; speed will be updated in processLocationData
        } else if useAccelerometer && useGPS {
            // Use Kalman filter to fuse data
            if kalmanFilter == nil {
                kalmanFilter = CustomDynamicKalmanFilter(processNoise: kalmanProcessNoise, measurementNoise: kalmanMeasurementNoise)
            }

            let acceleration = sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ)
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
            // Update Kalman filter
            if let kalmanFilter = kalmanFilter {
                kalmanFilter.updateWithGPS(speedMeasurement: gpsSpeed, gpsAccuracy: location.horizontalAccuracy, gpsAccuracyThreshold: gpsAccuracyThreshold)
                currentSpeed = max(0, kalmanFilter.estimatedSpeed)
            }
        } else if useGPS && !useAccelerometer {
            // Use GPS speed directly
            currentSpeed = gpsSpeed
        }
    }
}
//import Foundation
//import CoreMotion
//import CoreLocation
//
//class SpeedCalculator {
//    private var lastUpdateTime: TimeInterval = Date().timeIntervalSince1970
//    var currentSpeed: Double = 0.0
//    private var isSessionActive: Bool = false
//    private var kalmanFilter = BasicKalmanFilter()
//    
//    // MARK: - Session Control
//    func startSession() {
//        isSessionActive = true
//        lastUpdateTime = Date().timeIntervalSince1970
//    }
//
//    func stopSession() {
//        isSessionActive = false
//        kalmanFilter.reset()
//    }
//
//    func processDeviceMotionData(_ data: CMDeviceMotion) {
//        guard isSessionActive else { return }
//
//        let currentTime = Date().timeIntervalSince1970
//        let deltaTime = currentTime - lastUpdateTime
//        lastUpdateTime = currentTime
//
//        // Convert accelerometer data from G's to m/s²
//        let accelX = data.userAcceleration.x * 9.81
//        let accelY = data.userAcceleration.y * 9.81
//        let accelZ = data.userAcceleration.z * 9.81
//
//        // Calculate total acceleration magnitude
//        let totalAcceleration = sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ)
//
//        // Predict speed using accelerometer data
//        kalmanFilter.predict(acceleration: totalAcceleration, deltaTime: deltaTime)
//        currentSpeed = max(0, kalmanFilter.estimatedSpeed)
//    }
//
//    func processLocationData(_ location: CLLocation) {
//        guard isSessionActive else { return }
//
//        if location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 100 {
//            let gpsSpeed = max(location.speed, 0)
//            kalmanFilter.updateWithGPS(speedMeasurement: gpsSpeed)
//            currentSpeed = max(0, kalmanFilter.estimatedSpeed)
//        }
//    }
//}
//import Foundation
//import CoreMotion
//import CoreLocation
//
//class SpeedCalculator {
//    private var lastUpdateTime: TimeInterval = Date().timeIntervalSince1970
//    var currentSpeed: Double = 0.0
//    private var kalmanFilter = AdvancedKalmanFilter()
//    
//    // New boolean variable to control calculation method
//    var useXAxisOnly: Bool = true
//
//    // Variables for sensor offset recalibration
//    public var accelOffsetX: Double = 0.0
//    public var accelOffsetY: Double = 0.0
//    public var accelOffsetZ: Double = 0.0
//
//    public var rotationOffsetX: Double = 0.0
//    public var rotationOffsetY: Double = 0.0
//    public var rotationOffsetZ: Double = 0.0
//
//    private var offsetSamplingStartTime: TimeInterval?
//    private var offsetsCalculated = false
//    private var isRecalculatingOffsets = false
//    private var lastOffsetCalculationTime: TimeInterval = 0.0
//
//    // Data buffers for offset calculation
//    private var offsetSamplesAccelX: [Double] = []
//    private var offsetSamplesAccelY: [Double] = []
//    private var offsetSamplesAccelZ: [Double] = []
//
//    private var offsetSamplesRotationX: [Double] = []
//    private var offsetSamplesRotationY: [Double] = []
//    private var offsetSamplesRotationZ: [Double] = []
//    
//    
//
//    // Initialize isSessionActive to true
//    private var isSessionActive: Bool = true
//
//    // MARK: - Session Control
//    func startSession() {
//        isSessionActive = true
//        lastUpdateTime = Date().timeIntervalSince1970
//        resetOffsets()
//        kalmanFilter.reset()
//    }
//
//    func stopSession() {
//        isSessionActive = false
//        kalmanFilter.reset()
//    }
//
//    func resetOffsets() {
//        accelOffsetX = 0.0
//        accelOffsetY = 0.0
//        accelOffsetZ = 0.0
//        rotationOffsetX = 0.0
//        rotationOffsetY = 0.0
//        rotationOffsetZ = 0.0
//
//        offsetsCalculated = false
//        isRecalculatingOffsets = false
//        offsetSamplingStartTime = nil
//        lastOffsetCalculationTime = 0.0
//
//        offsetSamplesAccelX.removeAll()
//        offsetSamplesAccelY.removeAll()
//        offsetSamplesAccelZ.removeAll()
//        offsetSamplesRotationX.removeAll()
//        offsetSamplesRotationY.removeAll()
//        offsetSamplesRotationZ.removeAll()
//    }
//
//    func processDeviceMotionData(_ data: CMDeviceMotion) {
//        let currentTime = Date().timeIntervalSince1970
//        let deltaTime = currentTime - lastUpdateTime
//        lastUpdateTime = currentTime
//
//        // Recalculate offsets every 30 seconds
//        if !offsetsCalculated || (currentTime - lastOffsetCalculationTime >= 30.0 && !isRecalculatingOffsets) {
//            isRecalculatingOffsets = true
//            offsetSamplingStartTime = currentTime
//
//            offsetSamplesAccelX.removeAll()
//            offsetSamplesAccelY.removeAll()
//            offsetSamplesAccelZ.removeAll()
//            offsetSamplesRotationX.removeAll()
//            offsetSamplesRotationY.removeAll()
//            offsetSamplesRotationZ.removeAll()
//        }
//
//        if isRecalculatingOffsets {
//            // Collect samples
//            offsetSamplesAccelX.append(data.userAcceleration.x)
//            offsetSamplesAccelY.append(data.userAcceleration.y)
//            offsetSamplesAccelZ.append(data.userAcceleration.z)
//
//            offsetSamplesRotationX.append(data.rotationRate.x)
//            offsetSamplesRotationY.append(data.rotationRate.y)
//            offsetSamplesRotationZ.append(data.rotationRate.z)
//
//            // Collect samples over 2 seconds
//            if currentTime - offsetSamplingStartTime! >= 2.0 {
//                // Calculate average offsets
//                accelOffsetX = offsetSamplesAccelX.reduce(0, +) / Double(offsetSamplesAccelX.count)
//                accelOffsetY = offsetSamplesAccelY.reduce(0, +) / Double(offsetSamplesAccelY.count)
//                accelOffsetZ = offsetSamplesAccelZ.reduce(0, +) / Double(offsetSamplesAccelZ.count)
//
//                rotationOffsetX = offsetSamplesRotationX.reduce(0, +) / Double(offsetSamplesRotationX.count)
//                rotationOffsetY = offsetSamplesRotationY.reduce(0, +) / Double(offsetSamplesRotationY.count)
//                rotationOffsetZ = offsetSamplesRotationZ.reduce(0, +) / Double(offsetSamplesRotationZ.count)
//
//                offsetsCalculated = true
//                lastOffsetCalculationTime = currentTime
//                isRecalculatingOffsets = false
//
//                // Optionally, print the offsets for debugging
//                print("Offsets recalculated:")
//                print("Accel Offsets - X: \(accelOffsetX), Y: \(accelOffsetY), Z: \(accelOffsetZ)")
//                print("Rotation Offsets - X: \(rotationOffsetX), Y: \(rotationOffsetY), Z: \(rotationOffsetZ)")
//            }
//            // Continue with raw data during offset calculation
//        }
//
//        // Use adjusted data if offsets are calculated, else use raw data
//        var adjustedAccelX = ((data.userAcceleration.x - (offsetsCalculated ? accelOffsetX : 0.0)) * 9.81)
//        let adjustedAccelY = ((data.userAcceleration.y - (offsetsCalculated ? accelOffsetY : 0.0)) * 9.81)
//        let adjustedAccelZ = ((data.userAcceleration.z - (offsetsCalculated ? accelOffsetZ : 0.0)) * 9.81)
////        var horizontalAcceleration: Double
////
////        if useXAxisOnly {
////            // Use only the x-axis acceleration
////            horizontalAcceleration = adjustedAccelX
////        } else {
////            // Rotate acceleration into the horizontal plane
////            let rotationMatrix = data.attitude.rotationMatrix
////            let accelXRef = rotationMatrix.m11 * adjustedAccelX + rotationMatrix.m12 * adjustedAccelY + rotationMatrix.m13 * adjustedAccelZ
////            let accelYRef = rotationMatrix.m21 * adjustedAccelX + rotationMatrix.m22 * adjustedAccelY + rotationMatrix.m23 * adjustedAccelZ
////
////            // Calculate horizontal acceleration magnitude
////            horizontalAcceleration = sqrt(accelXRef * accelXRef + accelYRef * accelYRef)
////        }
////        // Use adjusted data if offsets are calculated, else use raw data
////        adjustedAccelX = ((data.userAcceleration.x - (offsetsCalculated ? accelOffsetX : 0.0)) * 9.81)
////
////        // Use only the x-axis acceleration
////        let acceleration = adjustedAccelX
////
////        // Integrate acceleration to get speed
////        currentSpeed += acceleration * deltaTime
////
////        // Apply simple drift correction: if speed is negative, set to zero
////        if currentSpeed < 0 {
////            currentSpeed = 0.0
////        }
//
//        // Print accelerometer estimate
////        print("Horizontal Acceleration: \(horizontalAcceleration) m/s²")
////        print("Estimated Speed from Accelerometer: \(currentSpeed) m/s")
//    }
//
//    func processLocationData(_ location: CLLocation) {
//       
//            if location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 100 {
//                let gpsSpeed = max(location.speed, 0)
//                let gpsAccuracy = location.horizontalAccuracy
//                
//                currentSpeed = max(0, gpsSpeed)
//                
//                let gps1Speed = location.speed // Speed in meters per second
//                let speed1Accuracy = location.speedAccuracy // Accuracy in meters per second
//
//                let current1Speed = max(gps1Speed, 0) // Ensure non-negative speed
//                print ("Current Speed: \(currentSpeed), \(current1Speed)")
//            
//                
//            
//        }
//    }
//
//    // Optionally, provide access to the adjusted rotation rates for other scripts
//    func getAdjustedRotationRates() -> (x: Double, y: Double, z: Double) {
//        return (x: rotationOffsetX, y: rotationOffsetY, z: rotationOffsetZ)
//    }
//}
//
