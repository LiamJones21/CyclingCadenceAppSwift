//
//  WatchViewModel.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// WatchViewModel.swift
// CyclingCadenceApp

import Foundation
import Combine
import CoreMotion
import CoreLocation
import HealthKit
import WatchConnectivity

// Import Protocols and Models
// Ensure you import 'Protocols.swift' and 'Models.swift'

class WatchViewModel: NSObject, ObservableObject, HealthKitManagerDelegate, SensorManagerDelegate, ConnectivityManagerDelegate, PredictionManagerDelegate, LocationManagerDelegate {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var currentSpeed: Double = 0.0
    @Published var currentGear: Int = 0
    @Published var currentTerrain: String = "Road"
    @Published var currentCadence: Double = 0.0
    @Published var isStanding: Bool = false
    @Published var dataPointCount: Int = 0
    @Published var settingsReceived: Bool = false
    @Published var isPhoneConnected: Bool = false
    @Published var recordingStateLastChanged: Date = Date()
    @Published var sessionActive: Bool = false
    @Published var accelerometerData: CMDeviceMotion?
    @Published var accelerometerDataSaved: CMAccelerometerData?

    
    @Published var isPredicting: Bool = false
    @Published var selectedModel: ModelConfig?
    @Published var sessionDuration: String = "00:00"
    @Published var gearRatios: [String] = []
    @Published var wheelCircumference: Double = 2.1 // Default value in meters

    // Managers
    private let healthKitManager = HealthKitManager()
    private let sensorManager = SensorManager()
    private let speedCalculator = SpeedCalculator()
    private let connectivityManager = ConnectivityManager()
    private let predictionManager = PredictionManager()
    private let dataCollector: DataCollector

        
    private let locationManager = LocationManager()

    // Timer for updating session duration
    private var durationTimer: Timer?

    override init() {
        dataCollector = DataCollector(speedCalculator: speedCalculator)
        super.init()
        setup()
    }

    func setup() {
        healthKitManager.delegate = self
        sensorManager.delegate = self
        connectivityManager.delegate = self
        predictionManager.delegate = self
        locationManager.delegate = self

        connectivityManager.setup()
        sensorManager.setup()
        locationManager.setup()
        healthKitManager.authorizeHealthKit()

        // Start sensors immediately to calculate speed all the time
        sensorManager.startSensors()
    }

    // MARK: - Recording Control Methods

    func startRecording(synchronized: Bool = true) {
        healthKitManager.startWorkout()
        // sensorManager.startSensors() // Already started
        locationManager.startUpdatingLocation()
        dataCollector.resetData()
        startDurationTimer()
        speedCalculator.reset() // Reset accelerometer data average

        // Update published properties
        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingStateLastChanged = Date()
            self.sessionActive = true
        }
        // Synchronize state with phone if needed
        if synchronized && isPhoneConnected {
            connectivityManager.sendRecordingState(isRecording: isRecording, timestamp: recordingStateLastChanged)
        }
    }

    func stopRecording(synchronized: Bool = true) {
        healthKitManager.stopWorkout()
        // sensorManager.stopSensors() // Keep sensors running
        locationManager.stopUpdatingLocation()
        stopDurationTimer()
        speedCalculator.stopSession() // Stop session in speed calculator

        // Update published properties
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingStateLastChanged = Date()
            self.sessionActive = false
        }
        // Send collected data to phone
        sendDataToPhone()
        // Synchronize state with phone if needed
        if synchronized && isPhoneConnected {
            connectivityManager.sendRecordingState(isRecording: isRecording, timestamp: recordingStateLastChanged)
        }
    }

    // MARK: - Duration Timer Methods

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateSessionDuration()
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func updateSessionDuration() {
        // Calculate and update session duration
        let elapsed: TimeInterval
        if isPredicting, let startTime = predictionManager.predictionStartTime {
            elapsed = Date().timeIntervalSince(startTime)
        } else if isRecording, let startTime = healthKitManager.workoutStartTime {
            elapsed = Date().timeIntervalSince(startTime)
        } else {
            elapsed = 0
        }
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        DispatchQueue.main.async {
            self.sessionDuration = String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - SensorManagerDelegate

        func didUpdateDeviceMotionData(_ data: CMDeviceMotion) {
            DispatchQueue.main.async {
                self.accelerometerData = data // You might need to adjust this if you still use accelerometerData elsewhere
            }
            speedCalculator.processDeviceMotionData(data)
            DispatchQueue.main.async {
                self.currentSpeed = self.speedCalculator.currentSpeed
            }

            // Continue to estimate cadence
            DispatchQueue.main.async {
                self.currentCadence = self.estimateCadence() ?? 0.0
            }

            // Collect data only if recording
            if isRecording {
                dataCollector.collectData(
                    deviceMotionData: data,
                    speed: speedCalculator.currentSpeed,
                    gear: currentGear,
                    terrain: currentTerrain,
                    isStanding: isStanding,
                    location: locationManager.currentLocation
                )
                DispatchQueue.main.async {
                    self.dataPointCount = self.dataCollector.dataCount
                }

                // Batch sending logic
                if dataCollector.getUnsentData().count >= 500 {
                    sendDataToPhone()
                }
            }
        }
//    func estimateCadence() -> Double? {
//        if currentGear == 0 {
//            return 0.0 // Cadence is 0 when freewheeling
//        }
//
//        guard !gearRatios.isEmpty else { return 0.0 }
//        let currentGearIndex = currentGear - 1
//        guard currentGearIndex >= 0 && currentGearIndex < gearRatios.count,
//              let gearRatio = Double(gearRatios[currentGearIndex]),
//              wheelCircumference > 0 else { return 0.0 }
//
//        // Calculate cadence (RPM)
//        let cadence = (currentSpeed / wheelCircumference) * gearRatio * 60
//        return cadence
//    }
    // MARK: - Cadence Estimation
    
    func estimateCadence() -> Double? {
        return dataCollector.estimateCadence()
    }

    // MARK: - Data Sending

    func sendDataToPhone() {
        let unsentData = dataCollector.getUnsentData()
        if !unsentData.isEmpty {
            connectivityManager.sendCollectedData(unsentData)
            dataCollector.clearUnsentData()
        }
    }

    // MARK: - ConnectivityManagerDelegate

    func didUpdateConnectionStatus(isConnected: Bool) {
        DispatchQueue.main.async {
            self.isPhoneConnected = isConnected
        }
    }

    func didReceiveRecordingState(isRecording: Bool, timestamp: Date) {
        // Handle synchronization of recording state
        if timestamp > recordingStateLastChanged {
            if isRecording != self.isRecording {
                recordingStateLastChanged = timestamp
                if isRecording {
                    startRecording(synchronized: false)
                } else {
                    stopRecording(synchronized: false)
                }
            }
        } else if timestamp < recordingStateLastChanged {
            // Our state is newer, send it to the phone
            connectivityManager.sendRecordingState(isRecording: self.isRecording, timestamp: self.recordingStateLastChanged)
        }
    }

    func didReceiveMessage(_ message: [String: Any]) {
        DispatchQueue.main.async {
            // Handle recording state if present
            if let isRecording = message["isRecording"] as? Bool,
               let timestamp = message["recordingStateLastChanged"] as? TimeInterval {
                let date = Date(timeIntervalSince1970: timestamp)
                self.didReceiveRecordingState(isRecording: isRecording, timestamp: date)
                return
            }

            // Handle settings updates
            var settingsUpdated = false

            if let currentGear = message["currentGear"] as? Int {
                self.currentGear = currentGear
                settingsUpdated = true
            }

            if let currentTerrain = message["currentTerrain"] as? String {
                self.currentTerrain = currentTerrain
                settingsUpdated = true
            }

            if let isStanding = message["isStanding"] as? Bool {
                self.isStanding = isStanding
                settingsUpdated = true
            }

            if let gearRatios = message["gearRatios"] as? [String] {
                self.gearRatios = gearRatios
                self.dataCollector.gearRatios = gearRatios // Update DataCollector
                settingsUpdated = true
            }

            if let wheelCircumference = message["wheelCircumference"] as? Double {
                self.wheelCircumference = wheelCircumference
                self.dataCollector.wheelCircumference = wheelCircumference // Update DataCollector
                settingsUpdated = true
            }

            if settingsUpdated {
                self.settingsReceived = true
                print("Settings updated from phone")
            }
        }
    }

    // MARK: - PredictionManagerDelegate

    func didReceivePredictionResult(_ result: PredictionResult) {
        // Handle prediction result
        // For example, send the result to the phone
        connectivityManager.sendPredictionResult(result)
    }

    // MARK: - LocationManagerDelegate

    func didUpdateLocation(_ location: CLLocation) {
        speedCalculator.processLocationData(location)
    }

    // MARK: - HealthKitManagerDelegate

    func didStartWorkout() {
        // Handle workout start if needed
        print("Workout started")
    }

    func didEndWorkout() {
        // Handle workout end if needed
        print("Workout ended")
    }
    
    
}
