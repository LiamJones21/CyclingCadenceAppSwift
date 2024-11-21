//
//
//
//
//  SpeedCalculator.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/3/24.
//

import Foundation
import CoreMotion
import CoreLocation

class SpeedCalculator: NSObject, CLLocationManagerDelegate {
    // MARK: - Properties
    private var motionManager = CMMotionManager()
    private var locationManager = CLLocationManager()

    private var lastUpdateTime: TimeInterval = Date().timeIntervalSince1970
    private var isSessionActive: Bool = false

    // Accelerometer offsets
    public var accelOffsetX: Double = 0.0
    public var accelOffsetY: Double = 0.0
    public var accelOffsetZ: Double = 0.0

    // Rotation rate offsets
    public var rotationOffsetX: Double = 0.0
    public var rotationOffsetY: Double = 0.0
    public var rotationOffsetZ: Double = 0.0

    // Offset calculation variables
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

    // Speed calculation variables
    private var filteredAcceleration: Double = 0.0
    private var sensorSpeed: Double = 0.0
    public var gpsSpeed: Double = 0.0
    public var currentSpeed: Double = 0.0 // Publicly accessible speed

    // Kalman filter variables
    private var kalmanSpeed: Double = 0.0
    private var kalmanErrorCovariance: Double = 1.0

    // Movement confidence variables
    private var lowConfidenceStartTime: TimeInterval?
    private let lowConfidenceDurationThreshold: TimeInterval = 5.0 // Adjust as needed

    // MARK: - Configurable Properties (Settings)
    // These properties can be set from the WatchViewModel
    public var useAccelerometer: Bool = true
    public var useGPS: Bool = true

    public var accelerometerTuningValue: Double = 1.0
    public var accelerometerWeightingX: Double = 1.0
    public var accelerometerWeightingY: Double = 1.0
    public var accelerometerWeightingZ: Double = 1.0

    public var useLowPassFilter: Bool = false
    public var lowPassFilterAlpha: Double = 0.1

    public var kalmanProcessNoise: Double = 1e-3
    public var kalmanMeasurementNoise: Double = 1e-1
    public var gpsAccuracyLowerBound: Double = 5.0
    public var gpsAccuracyUpperBound: Double = 20.0
    
    public var GPSSpeedEstimateAccuracy: Double = 0.0
    
    // Hybrid Speed Calculation
    private var lastUpdateTime1: TimeInterval = Date().timeIntervalSince1970
    // Low-pass filter for accelerometer data
    private var filteredAcceleration1: Double = 0.0
    private let filterFactor: Double = 0.1
    private var hybridSpeed: Double {
        if sensorOffset == 0.0 {
            sensorOffset = sensorSpeed
        }
        let gpsSpeedAvailable = gpsSpeed > 0.5 // Threshold for considering GPS speed reliable (0.5 m/s)
        let gpsWeight: Double = gpsSpeedAvailable ? 0.8 : 0.0
        let sensorWeight: Double = gpsSpeedAvailable ? 0.2 : 1.0
        print("Sensor Speed: \(sensorSpeed), GPS Speed: \(gpsSpeed), Hybrid Speed: \(gpsSpeed * gpsWeight) + (sensorSpeed * sensorWeight)")
        return (gpsSpeed * gpsWeight) + ((sensorSpeed - sensorOffset) * sensorWeight)
    }
    private var isStarted = false
    private var sensorOffset: Double = -1.76


    // MARK: - Session Control
    func reset() {
        sensorSpeed = 0.0
        gpsSpeed = 0.0
        kalmanSpeed = 0.0
        kalmanErrorCovariance = 1.0
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

        // Reset sensor variables
        filteredAcceleration = 0.0
    }

    func stopSession() {
        isSessionActive = false
        motionManager.stopDeviceMotionUpdates()
        locationManager.stopUpdatingLocation()
    }

    func startSession() {
        reset()
        startMotionUpdates()
        startLocationUpdates()
    }

    // MARK: - Motion Updates
    private func startMotionUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 50.0 // 50 Hz
            motionManager.startDeviceMotionUpdates()
        }
    }

    // MARK: - Location Updates
    private func startLocationUpdates() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - Process Device Motion Data
    func processDeviceMotionData(_ data: CMDeviceMotion) {
        calculateSpeed(accelData: data.userAcceleration)
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
        let adjustedAccelX = (data.userAcceleration.x - accelOffsetX) * accelerometerWeightingX
        let adjustedAccelY = (data.userAcceleration.y - accelOffsetY) * accelerometerWeightingY
        let adjustedAccelZ = (data.userAcceleration.z - accelOffsetZ) * accelerometerWeightingZ

//        // Calculate the magnitude of the adjusted acceleration vector
//        var accelerationMagnitude = sqrt(pow(adjustedAccelX, 2) + pow(adjustedAccelY, 2) + pow(adjustedAccelZ, 2))
//
//        // Apply tuning value
//        accelerationMagnitude *= accelerometerTuningValue
//
//        // Apply low-pass filter if enabled
//        if useLowPassFilter {
//            filteredAcceleration = (lowPassFilterAlpha * accelerationMagnitude) + ((1 - lowPassFilterAlpha) * filteredAcceleration)
//        } else {
//            filteredAcceleration = accelerationMagnitude
//        }
//
//        // Determine the direction of acceleration (positive or negative)
//        let signAcceleration = (adjustedAccelX + adjustedAccelY + adjustedAccelZ) >= 0 ? 1.0 : -1.0
//
//        // Estimate speed changes based on filtered acceleration
//        if useAccelerometer {
//            sensorSpeed += signAcceleration * filteredAcceleration * deltaTime * 9.81 // Convert to m/s^2 and integrate to get speed
//
//            // Apply damping to prevent drift
//            sensorSpeed *= 0.99
//
//            // Limit sensor speed to non-negative values
//            if sensorSpeed < 0 {
//                sensorSpeed = 0.0
//            }
//        }
//
//        // Update current speed estimate using Kalman filter
//        currentSpeed = kalmanFilterUpdate(sensorSpeedMeasurement: sensorSpeed)
    }

    // MARK: - Process Location Data
    func processLocationData(_ location: CLLocation) {
        if useGPS, let horizontalAccuracy = location.horizontalAccuracy as CLLocationAccuracy?, horizontalAccuracy >= gpsAccuracyLowerBound, horizontalAccuracy <= gpsAccuracyUpperBound {
            //            gpsSpeed = max(location.speed, 0)
            //            // Update current speed estimate using Kalman filter
            ////            currentSpeed = kalmanFilterUpdate(gpsSpeedMeasurement: gpsSpeed)
            //            GPSSpeedEstimateAccuracy = horizontalAccuracy
            gpsSpeed = max (0, location.speed)
            // Speed in m/s from GPS
            DispatchQueue.main.async {
                self.currentSpeed = self.hybridSpeed
            }
            GPSSpeedEstimateAccuracy = location.horizontalAccuracy
            
            
        }
    }

    // Reset speed only
    func resetSpeedOnly() {
        sensorSpeed = 0.0
        gpsSpeed = 0.0
        kalmanSpeed = 0.0
        kalmanErrorCovariance = 1.0
        currentSpeed = 0.0
    }
    
    
    // MARK: - Sensor-based Speed Calculation (using accelerometer)
    func calculateSpeed(accelData: CMAcceleration) {
        //        Calculate the magnitude of the acceleration vector
        if !useAccelerometer { return }
        let accelerationMagnitude = sqrt(pow(accelData.x, 2) +
                                         pow(accelData.y, 2) +
                                         pow(accelData.z, 2)) - 1.0 // Subtract gravity
        // Apply low-pass filter
        filteredAcceleration = (filterFactor * accelerationMagnitude) + ((1 - filterFactor) * filteredAcceleration)
        // Estimate speed changes based on filtered acceleration
        let currentTime = Date().timeIntervalSince1970
        let deltaTime = currentTime - lastUpdateTime1
        lastUpdateTime1 = currentTime
        sensorSpeed += filteredAcceleration * deltaTime * 9.81 // Convert to m/s^2 and integrate to get speed
        // Apply damping to prevent drift
        sensorSpeed *= 0.9
        
        
        
        DispatchQueue.main.async {
            self.currentSpeed = self.hybridSpeed
        }
        return
    }
    

    // MARK: - Kalman Filter Implementation
    private func kalmanFilterUpdate(sensorSpeedMeasurement: Double? = nil, gpsSpeedMeasurement: Double? = nil) -> Double {
        // Predict
        let predictedSpeed = kalmanSpeed
        let predictedErrorCovariance = kalmanErrorCovariance + kalmanProcessNoise

        var measurement: Double = predictedSpeed
        var measurementError: Double = predictedErrorCovariance

        if let gpsSpeed = gpsSpeedMeasurement {
            // GPS measurement update
            measurement = gpsSpeed
            measurementError = kalmanMeasurementNoise
        } else if let sensorSpeed = sensorSpeedMeasurement {
            // Sensor measurement update
            measurement = sensorSpeed
            measurementError = kalmanMeasurementNoise * 10 // Sensor data is less accurate
        }

        // Update
        let kalmanGain = predictedErrorCovariance / (predictedErrorCovariance + measurementError)
        kalmanSpeed = predictedSpeed + kalmanGain * (measurement - predictedSpeed)
        kalmanErrorCovariance = (1 - kalmanGain) * predictedErrorCovariance

        return kalmanSpeed
    }

    // MARK: - CLLocationManagerDelegate Methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            processLocationData(location)
        }
    }
}
