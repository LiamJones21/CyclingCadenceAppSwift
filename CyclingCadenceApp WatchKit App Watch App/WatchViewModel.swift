
//  Created by Jones, Liam on 20/10/2024.
// WatchViewModel.swift
// CyclingCadenceApp

import Foundation
import Combine
import CoreMotion
import CoreLocation
import HealthKit
import WatchConnectivity
import SwiftUI

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
    
    // MARK: - Settings Properties
    @Published var useAccelerometer: Bool = false
    @Published var useGPS: Bool = true

    // Accelerometer settings
    @Published var accelerometerTuningValue: Double = 1.0
    @Published var accelerometerWeightingX: Double = 1.0
    @Published var accelerometerWeightingY: Double = 1.0
    @Published var accelerometerWeightingZ: Double = 1.0
    @Published var useLowPassFilter: Bool = false
    @Published var lowPassFilterAlpha: Double = 0.1

    // Kalman filter settings
    @Published var kalmanProcessNoise: Double = 0.1
    @Published var kalmanMeasurementNoise: Double = 0.1
    @Published var gpsAccuracyLowerBound: Double = 5.0
    @Published var gpsAccuracyUpperBound: Double = 20.0

    // Managers
    private let healthKitManager = HealthKitManager()
    private let sensorManager = SensorManager()
    private let speedCalculator = SpeedCalculator()
    private let connectivityManager = ConnectivityManager()
    private let predictionManager = PredictionManager()
    private let dataCollector: DataCollector

    var sendingBatches = false

        
    private let locationManager = LocationManager()

    // Timer for updating session duration
    private var durationTimer: Timer?

    override init() {
        dataCollector = DataCollector(speedCalculator: speedCalculator)
        super.init()
        loadSettings()
        setup()
        observeSettingsChanges()
    }
    // MARK: - Settings Persistence

        func loadSettings() {
            let defaults = UserDefaults.standard
            useAccelerometer = defaults.bool(forKey: "useAccelerometer")
            useGPS = defaults.bool(forKey: "useGPS")

            accelerometerTuningValue = defaults.double(forKey: "accelerometerTuningValue")
            accelerometerWeightingX = defaults.double(forKey: "accelerometerWeightingX")
            accelerometerWeightingY = defaults.double(forKey: "accelerometerWeightingY")
            accelerometerWeightingZ = defaults.double(forKey: "accelerometerWeightingZ")
            useLowPassFilter = defaults.bool(forKey: "useLowPassFilter")
            lowPassFilterAlpha = defaults.double(forKey: "lowPassFilterAlpha")

            kalmanProcessNoise = defaults.double(forKey: "kalmanProcessNoise")
            kalmanMeasurementNoise = defaults.double(forKey: "kalmanMeasurementNoise")
            gpsAccuracyLowerBound = defaults.double(forKey: "gpsAccuracyLowerBound")
            gpsAccuracyUpperBound = defaults.double(forKey: "gpsAccuracyUpperBound")
        }

        func saveSettings() {
            let defaults = UserDefaults.standard
            defaults.set(useAccelerometer, forKey: "useAccelerometer")
            defaults.set(useGPS, forKey: "useGPS")

            defaults.set(accelerometerTuningValue, forKey: "accelerometerTuningValue")
            defaults.set(accelerometerWeightingX, forKey: "accelerometerWeightingX")
            defaults.set(accelerometerWeightingY, forKey: "accelerometerWeightingY")
            defaults.set(accelerometerWeightingZ, forKey: "accelerometerWeightingZ")
            defaults.set(useLowPassFilter, forKey: "useLowPassFilter")
            defaults.set(lowPassFilterAlpha, forKey: "lowPassFilterAlpha")

            defaults.set(kalmanProcessNoise, forKey: "kalmanProcessNoise")
            defaults.set(kalmanMeasurementNoise, forKey: "kalmanMeasurementNoise")
            defaults.set(gpsAccuracyLowerBound, forKey: "gpsAccuracyLowerBound")
            defaults.set(gpsAccuracyUpperBound, forKey: "gpsAccuracyUpperBound")
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
        locationManager.startUpdatingLocation()

        // Start sensors immediately to calculate speed all the time
        sensorManager.startSensors()
        
    }

    func applySettingsToSpeedCalculator() {
            speedCalculator.useAccelerometer = useAccelerometer
            speedCalculator.useGPS = useGPS
            speedCalculator.accelerometerTuningValue = accelerometerTuningValue
            speedCalculator.accelerometerWeightingX = accelerometerWeightingX
            speedCalculator.accelerometerWeightingY = accelerometerWeightingY
            speedCalculator.accelerometerWeightingZ = accelerometerWeightingZ
            speedCalculator.useLowPassFilter = useLowPassFilter
            speedCalculator.lowPassFilterAlpha = lowPassFilterAlpha
            speedCalculator.kalmanProcessNoise = kalmanProcessNoise
            speedCalculator.kalmanMeasurementNoise = kalmanMeasurementNoise
            speedCalculator.gpsAccuracyLowerBound = gpsAccuracyLowerBound
            speedCalculator.gpsAccuracyUpperBound = gpsAccuracyUpperBound
        }

        // Observe changes to settings and update SpeedCalculator
        private var cancellables = Set<AnyCancellable>()
    // MARK: - Observe Settings Changes

        func observeSettingsChanges() {
            $useAccelerometer
                .sink { [weak self] _ in
                    self?.applySettingsToSpeedCalculator()
                    self?.saveSettings()
                }
                .store(in: &cancellables)

            $useGPS
                .sink { [weak self] _ in
                    self?.applySettingsToSpeedCalculator()
                    self?.saveSettings()
                }
                .store(in: &cancellables)

            $accelerometerTuningValue
                .sink { [weak self] _ in
                    self?.applySettingsToSpeedCalculator()
                    self?.saveSettings()
                }
                .store(in: &cancellables)

            $accelerometerWeightingX
                .sink { [weak self] _ in
                    self?.applySettingsToSpeedCalculator()
                    self?.saveSettings()
                }
                .store(in: &cancellables)

            $accelerometerWeightingY
                .sink { [weak self] _ in
                    self?.applySettingsToSpeedCalculator()
                    self?.saveSettings()
                }
                .store(in: &cancellables)

            $accelerometerWeightingZ
                .sink { [weak self] _ in
                    self?.applySettingsToSpeedCalculator()
                    self?.saveSettings()
                }
                .store(in: &cancellables)

            $useLowPassFilter
                .sink { [weak self] _ in
                    self?.applySettingsToSpeedCalculator()
                    self?.saveSettings()
                }
                .store(in: &cancellables)

            $lowPassFilterAlpha
                .sink { [weak self] _ in
                    self?.applySettingsToSpeedCalculator()
                    self?.saveSettings()
                }
                .store(in: &cancellables)

            $kalmanProcessNoise
                .sink { [weak self] _ in
                    self?.applySettingsToSpeedCalculator()
                    self?.saveSettings()
                }
                .store(in: &cancellables)

            $kalmanMeasurementNoise
                .sink { [weak self] _ in
                    self?.applySettingsToSpeedCalculator()
                    self?.saveSettings()
                }
                .store(in: &cancellables)

            $gpsAccuracyLowerBound
                .sink { [weak self] _ in
                    self?.applySettingsToSpeedCalculator()
                    self?.saveSettings()
                }
                .store(in: &cancellables)

            $gpsAccuracyUpperBound
                .sink { [weak self] _ in
                    self?.applySettingsToSpeedCalculator()
                    self?.saveSettings()
                }
                .store(in: &cancellables)
        }
    
    
    // MARK: - Recording Control Methods

    func startRecording(synchronized: Bool = true) {
        healthKitManager.startWorkout()
        // sensorManager.startSensors() // Already started
        locationManager.startUpdatingLocation()
        dataCollector.resetData()
        startDurationTimer()
//        speedCalculator.reset() // Reset accelerometer data average

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
//        locationManager.stopUpdatingLocation()
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
                self.accelerometerData = data // you still use accelerometerData elsewhere
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
                if dataCollector.getUnsentData().count >= 200 {
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
        if sendingBatches || !isPhoneConnected {return}
        
        self.sendingBatches = true
        let unsentData = dataCollector.getUnsentData()
        dataCollector.clearUnsentData()
        let batchSize = 300


        guard !unsentData.isEmpty else { return }

        var batches: [[CyclingData]] = []
        var currentBatch: [CyclingData] = []

        for dataPoint in unsentData {
            currentBatch.append(dataPoint)
            if currentBatch.count == batchSize {
                batches.append(currentBatch)
                currentBatch = []
            }
        }

        if !currentBatch.isEmpty {
            batches.append(currentBatch)
        }

        for batch in batches {
            connectivityManager.sendCollectedData(batch)
            print("Sending batch of data to phone... Batch size: \(batch.count)")
        }
        self.sendingBatches = false
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


