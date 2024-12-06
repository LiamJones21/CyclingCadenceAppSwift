
import Foundation
import Combine
import CoreMotion
import CoreLocation
import HealthKit
import WatchConnectivity
import SwiftUI
#if canImport(CoreHaptics)
import CoreHaptics
#endif
class WatchViewModel: NSObject, ObservableObject, HealthKitManagerDelegate, SensorManagerDelegate, ConnectivityManagerDelegate, PredictionManagerDelegate, LocationManagerDelegate {
    @Published var isRecording = false
    @Published var currentSpeed: Double = 0.0
    @Published var GPSSpeedEstimate: String = "0.000"
    @Published var GPSSpeedEstimateAccuracy: String = "0.000"
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

    // NEW: Prediction mode
    @Published var isPredicting: Bool = false
    @Published var predictedCadence: Double = 0.0
    @Published var predictedTerrain: String = "Road"
    @Published var predictedStance: Bool = false
    @Published var predictedGear: Int = 0

    @Published var selectedModel: ModelConfig?
    @Published var sessionDuration: String = "00:00"
    @Published var gearRatios: [String] = []
    @Published var wheelCircumference: Double = 2.1 // in meters

    // Settings Properties
    @Published var useAccelerometer: Bool = false
    @Published var useGPS: Bool = true
    @Published var accelerometerTuningValue: Double = 1.0
    @Published var accelerometerWeightingX: Double = 1.0
    @Published var accelerometerWeightingY: Double = 1.0
    @Published var accelerometerWeightingZ: Double = 1.0
    @Published var useLowPassFilter: Bool = false
    @Published var lowPassFilterAlpha: Double = 0.1
    @Published var kalmanProcessNoise: Double = 0.1
    @Published var kalmanMeasurementNoise: Double = 0.1
    @Published var gpsAccuracyLowerBound: Double = 5.0
    @Published var gpsAccuracyUpperBound: Double = 20.0

    private let healthKitManager = HealthKitManager()
    private let sensorManager = SensorManager()
    private let speedCalculator = SpeedCalculator()
    private let connectivityManager = ConnectivityManager()
    private let predictionManager = PredictionManager()
    private let dataCollector: DataCollector
    private let locationManager = LocationManager()

    var sendingBatches = false

    // Prediction handling
    private let predictionHandler = PredictionHandler()
    private var predictionTimer: Timer?
    // Haptic Engines
    #if canImport(CoreHaptics)
    private var hapticEngine: CHHapticEngine?
    #endif

    // Gear vibration control
    private var lastVibrationTime: Date = Date(timeIntervalSince1970: 0)
    private let vibrationInterval: TimeInterval = 10.0
    private var lastSuggestedGear: Int = 0

    private var durationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        dataCollector = DataCollector(speedCalculator: speedCalculator)
        super.init()
        loadSettings()
        setup()
        observeSettingsChanges()
        prepareHaptics()
    }

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

    func observeSettingsChanges() {
        $useAccelerometer.sink { [weak self] _ in self?.applySettingsAndSave() }.store(in: &cancellables)
        $useGPS.sink { [weak self] _ in self?.applySettingsAndSave() }.store(in: &cancellables)
        $accelerometerTuningValue.sink { [weak self] _ in self?.applySettingsAndSave() }.store(in: &cancellables)
        $accelerometerWeightingX.sink { [weak self] _ in self?.applySettingsAndSave() }.store(in: &cancellables)
        $accelerometerWeightingY.sink { [weak self] _ in self?.applySettingsAndSave() }.store(in: &cancellables)
        $accelerometerWeightingZ.sink { [weak self] _ in self?.applySettingsAndSave() }.store(in: &cancellables)
        $useLowPassFilter.sink { [weak self] _ in self?.applySettingsAndSave() }.store(in: &cancellables)
        $lowPassFilterAlpha.sink { [weak self] _ in self?.applySettingsAndSave() }.store(in: &cancellables)
        $kalmanProcessNoise.sink { [weak self] _ in self?.applySettingsAndSave() }.store(in: &cancellables)
        $kalmanMeasurementNoise.sink { [weak self] _ in self?.applySettingsAndSave() }.store(in: &cancellables)
        $gpsAccuracyLowerBound.sink { [weak self] _ in self?.applySettingsAndSave() }.store(in: &cancellables)
        $gpsAccuracyUpperBound.sink { [weak self] _ in self?.applySettingsAndSave() }.store(in: &cancellables)
    }

    private func applySettingsAndSave() {
        applySettingsToSpeedCalculator()
        saveSettings()
    }

    func startRecording(synchronized: Bool = true) {
        healthKitManager.startWorkout()
        locationManager.startUpdatingLocation()
        dataCollector.resetData()
        startDurationTimer()

        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingStateLastChanged = Date()
            self.sessionActive = true
        }
        if synchronized && self.isPhoneConnected {
            connectivityManager.sendRecordingState(isRecording: isRecording, timestamp: recordingStateLastChanged)
        }
    }

    func stopRecording(synchronized: Bool = true) {
        healthKitManager.stopWorkout()
        stopDurationTimer()
        speedCalculator.stopSession()

        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingStateLastChanged = Date()
            self.sessionActive = false
        }
        sendDataToPhone()
        if synchronized && isPhoneConnected {
            connectivityManager.sendRecordingState(isRecording: isRecording, timestamp: recordingStateLastChanged)
        }
    }

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
        let elapsed: TimeInterval
        if isPredicting {
            elapsed = predictionManager.predictionStartTime.map { Date().timeIntervalSince($0) } ?? 0
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

    func didUpdateDeviceMotionData(_ data: CMDeviceMotion) {
        DispatchQueue.main.async {
            self.accelerometerData = data
        }
        speedCalculator.processDeviceMotionData(data)
        DispatchQueue.main.async {
            self.currentSpeed = self.speedCalculator.currentSpeed
            self.GPSSpeedEstimate = String(format: "%.3f", self.speedCalculator.gpsSpeed)
            self.GPSSpeedEstimateAccuracy = String(format: "%.3f", self.speedCalculator.GPSSpeedEstimateAccuracy)
            self.currentCadence = self.estimateCadence() ?? 0.0
        }

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

            if dataCollector.getUnsentData().count >= 2000 {
                sendDataToPhone()
            }
        }

        // If predicting, accumulate data and run model when we have a full window
        if isPredicting {
            predictionHandler.addDataPoint(
                accel_x: data.userAcceleration.x,
                accel_y: data.userAcceleration.y,
                accel_z: data.userAcceleration.z,
                rotacc_x: data.rotationRate.x,
                rotacc_y: data.rotationRate.y,
                rotacc_z: data.rotationRate.z,
                speed: currentSpeed
            )

            if predictionHandler.isReadyForPrediction() {
                runPrediction()
            }
        }
    }

    func estimateCadence() -> Double? {
        return dataCollector.estimateCadence()
    }

    func sendDataToPhone() {
        if sendingBatches || !isPhoneConnected { return }
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
        }
        self.sendingBatches = false
    }

    func didUpdateConnectionStatus(isConnected: Bool) {
        DispatchQueue.main.async {
            self.isPhoneConnected = isConnected
        }
    }

    func didReceiveRecordingState(isRecording: Bool, timestamp: Date) {
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
            connectivityManager.sendRecordingState(isRecording: self.isRecording, timestamp: self.recordingStateLastChanged)
        }
    }

    func didReceiveMessage(_ message: [String: Any]) {
        DispatchQueue.main.async {
            if let isRecording = message["isRecording"] as? Bool,
               let ts = message["recordingStateLastChanged"] as? TimeInterval {
                let date = Date(timeIntervalSince1970: ts)
                self.didReceiveRecordingState(isRecording: isRecording, timestamp: date)
                return
            }

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
                self.dataCollector.gearRatios = gearRatios
                settingsUpdated = true
            }

            if let wheelCircumference = message["wheelCircumference"] as? Double {
                self.wheelCircumference = wheelCircumference
                self.dataCollector.wheelCircumference = wheelCircumference
                settingsUpdated = true
            }

            if settingsUpdated {
                self.settingsReceived = true
            }
        }
    }

    func didReceivePredictionResult(_ result: PredictionResult) {
        // Not used here since we handle predictions directly
    }

    func didUpdateLocation(_ location: CLLocation) {
        speedCalculator.processLocationData(location)
    }

    func didStartWorkout() {}
    func didEndWorkout() {}

    // MARK: Prediction Mode Control
    func startPredictionMode() {
        isPredicting = true
        predictionHandler.reset()
        predictionManager.predictionStartTime = Date()
        // Maybe select a model config if needed
        // selectedModel = ...
    }

    func stopPredictionMode() {
        isPredicting = false
        predictionManager.predictionStartTime = nil
    }

    func runPrediction() {
        guard let result = predictionHandler.runPrediction() else { return }
        DispatchQueue.main.async {
            self.predictedCadence = result.cadence
            self.predictedTerrain = result.terrain
            self.predictedStance = result.isStanding
            // From speed and predicted cadence, work out gear:
            self.predictedGear = self.estimateGear(cadence: self.predictedCadence, speed: self.currentSpeed)
            self.handleGearVibrationIfNeeded()
        }
    }

    func estimateGear(cadence: Double, speed: Double) -> Int {
        // If gear ratios known, invert the formula:
        // cadence (RPM) = (speed(m/s)/wheelCircumference)*gearRatio*60
        // gearRatio = (cadence/60 * wheelCircumference)/speed
        // Find closest gear ratio:
        guard !gearRatios.isEmpty, speed > 0.1 else { return 0 }
        let targetRatio = (cadence/60) * wheelCircumference / speed
        var bestGear = 1
        var bestDiff = Double.greatestFiniteMagnitude

        for (i, ratioStr) in gearRatios.enumerated() {
            if let ratio = Double(ratioStr) {
                let diff = abs(ratio - targetRatio)
                if diff < bestDiff {
                    bestDiff = diff
                    bestGear = i+1
                }
            }
        }
        return bestGear
    }

    // Haptics
    func prepareHaptics() {
            #if canImport(CoreHaptics)
            guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
            do {
                hapticEngine = try CHHapticEngine()
                try hapticEngine?.start()
            } catch {
                print("Failed to start Core Haptics engine: \(error.localizedDescription)")
            }
            #endif
        }

    func vibrate(style: HapticStyle) {
            #if canImport(CoreHaptics)
            if let hapticEngine = hapticEngine {
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                let duration: Double = (style == .long) ? 0.5 : 0.1
                let event = CHHapticEvent(eventType: .hapticContinuous,
                                          parameters: [intensity, sharpness],
                                          relativeTime: 0,
                                          duration: duration)
                do {
                    let pattern = try CHHapticPattern(events: [event], parameters: [])
                    let player = try hapticEngine.makePlayer(with: pattern)
                    try player.start(atTime: 0)
                    return
                } catch {
                    print("Failed to play haptic: \(error.localizedDescription)")
                }
            }
            #endif
            // Fallback for older devices
            vibrateFallback(style: style)
        }
    func vibrateFallback(style: HapticStyle) {
            let hapticType: WKHapticType = (style == .long) ? .failure : .success
            WKInterfaceDevice.current().play(hapticType)
        }

        enum HapticStyle {
            case short
            case long
        }

    // MARK: - Gear Vibration Control
        func handleGearVibrationIfNeeded() {
            let targetCadence = 70.0
            let currentTime = Date()
            let enoughTimePassed = currentTime.timeIntervalSince(lastVibrationTime) >= vibrationInterval

            let cadenceDiff = predictedCadence - targetCadence
            let suggestedGear = predictedGear

            if abs(cadenceDiff) > 5 { // threshold
                if enoughTimePassed || (suggestedGear != lastSuggestedGear) {
                    if cadenceDiff < 0 {
                        // Go up a gear: short vibration
                        vibrate(style: .short)
                    } else {
                        // Go down a gear: long vibration
                        vibrate(style: .long)
                    }
                    lastVibrationTime = currentTime
                    lastSuggestedGear = suggestedGear
                }
            }
        }
}
