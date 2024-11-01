//
//  WatchViewModel.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// WatchViewModel.swift

import Foundation
import CoreMotion
import CoreML
import WatchConnectivity
import Combine
import CoreLocation
import WatchKit
import HealthKit

class WatchViewModel: NSObject, ObservableObject, WCSessionDelegate, CLLocationManagerDelegate, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var currentSpeed: Double = 0.0 // m/s
    @Published var currentGear: Int = 0
    @Published var currentTerrain: String = "Road"
    @Published var isStanding: Bool = false
    @Published var dataPointCount: Int = 0
    @Published var settingsReceived: Bool = false
    @Published var isPhoneConnected: Bool = false
    @Published var recordingStateLastChanged: Date = Date()
    
    @Published var sessionActive: Bool = false
    private var timer: Timer?
    
    // Sensor data for display
    @Published var accelerometerData: CMAccelerometerData?
    
    // MARK: - Private Properties
    private let motionManager = CMMotionManager()
    private var sessionWC = WCSession.default
    private let locationManager = CLLocationManager()
    
    // Settings
    var gearRatios: [String] = []
    var wheelCircumference: Double = 2.1 // Default value in meters
    
    // Data Collection
    private var collectedData: [CyclingData] = []
    private var unsentData: [CyclingData] = []
    
    // For sensor speed calculation
    private var lastUpdateTime: TimeInterval = Date().timeIntervalSince1970
    private var filteredAcceleration: Double = 0.0
    private let filterFactor: Double = 0.1
    private var sensorSpeed: Double = 0.0
    
    // HealthKit Workout Session
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    // Timer for periodic data sending
    private var dataSendTimer: Timer?
    
    // Computed property for session duration
    var sessionDuration: String {
        let elapsed: TimeInterval
        if isPredicting, let startTime = predictionStartTime {
            elapsed = Date().timeIntervalSince(startTime)
        } else if isRecording, let startTime = recordingStartTime {
            elapsed = Date().timeIntervalSince(startTime)
        } else {
            return "00:00"
        }
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var recordingStartTime: Date?
    private var predictionStartTime: Date?
    
    // MARK: - Prediction Mode Properties
        @Published var isPredicting: Bool = false
        @Published var selectedModel: ModelConfig?
        var models: [ModelConfig] = []
        var predictionTimer: Timer?
        var predictionWindowData: [CMAccelerometerData] = []
    
    // MARK: - Initialization
    override init() {
        super.init()
        setup()
    }
    
    // MARK: - Setup Methods
    func setup() {
        setupWatchConnectivity()
        setupLocationManager()
        authorizeHealthKit()
    }
    
    // MARK: - HealthKit Authorization
    func authorizeHealthKit() {
        let typesToShare: Set = [
            HKObjectType.workoutType()
        ]
        
        let typesToRead: Set = [
            HKObjectType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if success {
                print("HealthKit authorization successful.")
            } else {
                print("HealthKit authorization failed: \(error?.localizedDescription ?? "No error")")
            }
        }
    }
    
    

        // MARK: - Prediction Control
        func startPrediction() {
            guard let model = selectedModel else { return }
            predictionStartTime = Date()
            isPredicting = true
            predictionWindowData.removeAll()
            startSensorUpdatesForPrediction()
        }

        func stopPrediction() {
            predictionStartTime = nil
            isPredicting = false
            stopSensorUpdatesForPrediction()
            selectedModel = nil
        }

        // MARK: - Sensor Updates for Prediction
        func startSensorUpdatesForPrediction() {
            motionManager.accelerometerUpdateInterval = 1.0 / 50.0 // 50 Hz
            motionManager.startAccelerometerUpdates()

            predictionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 50.0, repeats: true) { [weak self] _ in
                if let accelData = self?.motionManager.accelerometerData {
                    self?.handlePredictionSensorData(accelData: accelData)
                }
            }
        }

        func stopSensorUpdatesForPrediction() {
            motionManager.stopAccelerometerUpdates()
            predictionTimer?.invalidate()
            predictionTimer = nil
        }

        func handlePredictionSensorData(accelData: CMAccelerometerData) {
            guard let model = selectedModel else { return }

            predictionWindowData.append(accelData)

            // Check if we have enough data for a window
            if predictionWindowData.count >= model.config.windowSize {
                // Perform prediction
                let predictionResult = performPrediction(with: predictionWindowData, model: model)
                // Send prediction result to phone
                sendPredictionResultToPhone(predictionResult)
                // Remove data based on window step (overlap)
                predictionWindowData.removeFirst(model.config.windowStep)
            }
        }

        func performPrediction(with data: [CMAccelerometerData], model: ModelConfig) -> PredictionResult {
            // Placeholder implementation
            // Perform preprocessing and prediction using the model and config
            // For now, we will simulate prediction results

            let randomCadence = Double.random(in: 60...120)
            let randomGear = Int.random(in: 1...5)
            let randomTerrain = ["Road", "Gravel"].randomElement()!
            let randomPosition = Bool.random()

            return PredictionResult(
                timestamp: Date(),
                cadence: randomCadence,
                gear: randomGear,
                terrain: randomTerrain,
                isStanding: randomPosition,
                speed: currentSpeed
            )
        }

        func sendPredictionResultToPhone(_ result: PredictionResult) {
            if sessionWC.isReachable {
                do {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(result)
                    let dataDict: [String: Any] = ["predictionResult": data]
                    sessionWC.sendMessage(dataDict, replyHandler: nil, errorHandler: { error in
                        print("Error sending prediction result to phone: \(error.localizedDescription)")
                    })
                    print("Sent prediction result to phone")
                } catch {
                    print("Error encoding prediction result: \(error.localizedDescription)")
                }
            } else {
                print("Phone is not reachable")
            }
        }
    
    // MARK: - Workout Session Management
    func startRecording(synchronized: Bool = true) {
        guard workoutSession == nil else { return }
        recordingStartTime = Date()
        
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .cycling
        workoutConfiguration.locationType = .outdoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: workoutConfiguration)
            workoutBuilder = workoutSession!.associatedWorkoutBuilder()
            workoutSession!.delegate = self
            workoutBuilder!.delegate = self
            workoutBuilder!.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: workoutConfiguration)
            workoutSession!.startActivity(with: Date())
            workoutBuilder!.beginCollection(withStart: Date()) { (success, error) in
                // Handle errors if needed
            }
            print("Workout session started.")
            DispatchQueue.main.async {
                self.isRecording = true
                self.recordingStateLastChanged = Date()
                self.dataPointCount = 0
            }
            sessionActive = true
            startWatchDisplayTimer()
            startSensorUpdates()
            startDataSendTimer()
            if synchronized && isPhoneConnected {
                sendRecordingStateToPhone()
            }
        } catch {
            print("Failed to start workout session: \(error.localizedDescription)")
        }
    }
    
    func stopRecording(synchronized: Bool = true) {
        guard let workoutSession = workoutSession, let workoutBuilder = workoutBuilder else { return }
        recordingStartTime = nil
        workoutSession.end()
        workoutBuilder.endCollection(withEnd: Date()) { (success, error) in
            // Handle errors if needed
            self.workoutSession = nil
            self.workoutBuilder = nil
            print("Workout session ended.")
        }
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingStateLastChanged = Date()
        }
        sessionActive = false
        stopWatchDisplayTimer()
        stopSensorUpdates()
        stopDataSendTimer()
        if synchronized && isPhoneConnected {
            sendRecordingStateToPhone()
        }
        // Send collected data to phone when recording stops
        sendCollectedDataToPhone()
        // Reset collected data
        collectedData.removeAll()
        unsentData.removeAll()
        DispatchQueue.main.async {
            self.dataPointCount = 0
        }
    }
    
    private func startWatchDisplayTimer() {
        // Start a repeating timer to keep watch interface active
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            self.updateDisplay()
        }
    }
    
    private func stopWatchDisplayTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateDisplay() {
        // This method can toggle or update any interface elements, like an @Published variable
        // Forcing the interface to refresh
        sessionActive.toggle()
    }
    
    // MARK: - Sensor Management
    func startSensorUpdates() {
        motionManager.accelerometerUpdateInterval = 1.0 / 50.0
        
        let sensorQueue = OperationQueue()
        
        // Start accelerometer updates with handler
        if motionManager.isAccelerometerAvailable {
            motionManager.startAccelerometerUpdates(to: sensorQueue) { (accelData, error) in
                if let error = error {
                    print("Accelerometer error: \(error.localizedDescription)")
                    return
                }
                
                guard let accelData = accelData else {
                    print("No accelerometer data")
                    return
                }
                
                self.handleAccelerometerData(accelData)
            }
            print("Accelerometer updates started")
        } else {
            print("Accelerometer is not available.")
        }
    }
    
    func stopSensorUpdates() {
        motionManager.stopAccelerometerUpdates()
        print("Accelerometer updates stopped")
    }
    
    // MARK: - Accelerometer Data Handling
    func handleAccelerometerData(_ accelData: CMAccelerometerData) {
        DispatchQueue.main.async {
            self.accelerometerData = accelData // For display
        }
        self.updateSpeedFromSensorData(accelData: accelData)
        
        self.collectData(accelData: accelData)
        
        DispatchQueue.main.async {
            self.dataPointCount = self.collectedData.count
        }
    }
    
    func updateSpeedFromSensorData(accelData: CMAccelerometerData) {
        let accelerationMagnitude = sqrt(pow(accelData.acceleration.x, 2) +
                                         pow(accelData.acceleration.y, 2) +
                                         pow(accelData.acceleration.z, 2)) - 1.0 // Subtract gravity
        
        // Apply low-pass filter
        filteredAcceleration = (filterFactor * accelerationMagnitude) + ((1 - filterFactor) * filteredAcceleration)
        
        let currentTime = Date().timeIntervalSince1970
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        sensorSpeed += filteredAcceleration * deltaTime * 9.81 // Convert to m/s^2 and integrate to get speed
        
        // Apply damping to prevent drift
        sensorSpeed *= 0.9
        
        DispatchQueue.main.async {
            self.currentSpeed = max(0, self.sensorSpeed) // Ensure speed doesn't go negative
        }
    }
    
    func collectData(accelData: CMAccelerometerData) {
        let accelSensorData = SensorData(
            x: accelData.acceleration.x,
            y: accelData.acceleration.y,
            z: accelData.acceleration.z
        )
        
        let location = locationManager.location
        let locationData = location != nil ? LocationData(latitude: location!.coordinate.latitude, longitude: location!.coordinate.longitude) : nil
        
        let cadence = estimateCadence() ?? 0.0
        
        let cyclingData = CyclingData(
            timestamp: Date(),
            speed: currentSpeed,
            cadence: cadence,
            gear: currentGear,
            terrain: currentTerrain,
            isStanding: isStanding,
            accelerometerData: accelSensorData,
            location: locationData
        )
        
        collectedData.append(cyclingData)
        unsentData.append(cyclingData)
        
        // Send data in batches to prevent data loss during long sessions
        if unsentData.count >= 500 { // Adjust batch size as needed
            sendCollectedDataToPhone()
        }
    }
    
    // MARK: - Cadence Estimation
    func estimateCadence() -> Double? {
        if currentGear == 0 {
            return 0.0 // Cadence is 0 when freewheeling
        }
        
        guard !gearRatios.isEmpty else { return 0.0 }
        let currentGearIndex = currentGear - 1
        guard currentGearIndex >= 0 && currentGearIndex < gearRatios.count,
              let gearRatio = Double(gearRatios[currentGearIndex]),
              wheelCircumference > 0 else { return 0.0 }
        
        // Calculate cadence (RPM)
        let cadence = (currentSpeed / wheelCircumference) * gearRatio * 60
        return cadence
    }
    
    // MARK: - Data Synchronization
    private var isSendingData = false

    func sendCollectedDataToPhone() {
        guard !isSendingData else { return }
        isSendingData = true

        guard !unsentData.isEmpty else {
            print("No data to send to phone.")
            isSendingData = false
            return
        }
        
        if sessionWC.isReachable {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(unsentData)
                let dataDict: [String: Any] = ["cyclingData": data]
                
                sessionWC.transferUserInfo(dataDict)
                print("Transferred unsent data to phone. Data count: \(unsentData.count)")
                
                unsentData.removeAll()
                isSendingData = false
            } catch {
                print("Error encoding cycling data: \(error.localizedDescription)")
                isSendingData = false
            }
        } else {
            print("Phone is not reachable. Data will be sent when the connection is available.")
            isSendingData = false
        }
    }
    
    func sendRecordingStateToPhone() {
        if sessionWC.isReachable {
            let data: [String: Any] = [
                "isRecording": isRecording,
                "recordingStateLastChanged": recordingStateLastChanged.timeIntervalSince1970
            ]
            sessionWC.sendMessage(data, replyHandler: nil, errorHandler: { error in
                print("Error sending recording state to phone: \(error.localizedDescription)")
            })
            print("Sent recording state (\(isRecording)) to phone")
        } else {
            print("Phone is not reachable")
        }
    }
    
    func requestRecordingStateFromPhone() {
        if sessionWC.isReachable {
            let data: [String: Any] = ["request": "recordingState"]
            sessionWC.sendMessage(data, replyHandler: nil, errorHandler: { error in
                print("Error requesting recording state from phone: \(error.localizedDescription)")
            })
            print("Requested recording state from phone")
        } else {
            print("Phone is not reachable")
        }
    }
    
    // MARK: - Watch Connectivity Setup
    func setupWatchConnectivity() {
        if WCSession.isSupported() {
            sessionWC.delegate = self
            sessionWC.activate()
        }
    }
    
    // MARK: - Location Manager Setup
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - Data Send Timer Management
    func startDataSendTimer() {
        dataSendTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.sendCollectedDataToPhone()
        }
    }
    
    func stopDataSendTimer() {
        dataSendTimer?.invalidate()
        dataSendTimer = nil
    }
    
    // MARK: - WCSessionDelegate Methods
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneConnected = session.isReachable
            
            // Request recording state from phone upon activation
            self.sendRecordingStateToPhone()
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneConnected = session.isReachable
            print("Phone connection status changed: \(self.isPhoneConnected)")
            
            if self.isPhoneConnected {
                // Send any unsent data
                self.sendCollectedDataToPhone()
                
                // Synchronize recording state
                self.sendRecordingStateToPhone()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let request = message["request"] as? String {
                switch request {
                case "recordingState":
                    self.sendRecordingStateToPhone()
                case "unsentData":
                    self.sendCollectedDataToPhone()
                default:
                    break
                }
            } else {
                // Update recording state
                if let isRecordingFromPhone = message["isRecording"] as? Bool,
                   let recordingStateLastChangedFromPhone = message["recordingStateLastChanged"] as? TimeInterval {
                    
                    let phoneRecordingStateLastChanged = Date(timeIntervalSince1970: recordingStateLastChangedFromPhone)
                    
                    if phoneRecordingStateLastChanged > self.recordingStateLastChanged {
                        // The phone's recording state change is more recent
                        if self.isRecording != isRecordingFromPhone {
                            self.recordingStateLastChanged = phoneRecordingStateLastChanged
                            print("Recording state updated from phone: \(isRecordingFromPhone)")
                            
                            if isRecordingFromPhone {
                                self.startRecording(synchronized: false)
                            } else {
                                self.stopRecording(synchronized: false)
                            }
                        }
                    } else if phoneRecordingStateLastChanged < self.recordingStateLastChanged {
                        // Our recording state change is more recent, send it to the phone
                        self.sendRecordingStateToPhone()
                    } else {
                        // Timestamps are equal, do nothing
                    }
                }
                
                // Handle settings synchronization
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
                    settingsUpdated = true
                }
                
                if let wheelCircumference = message["wheelCircumference"] as? Double {
                    self.wheelCircumference = wheelCircumference
                    settingsUpdated = true
                }
                
                if settingsUpdated {
                    self.settingsReceived = true
                    print("Settings updated from phone")
                }
            }
            // Handle model loading
            if let data = message["models"] as? Data {
                do {
                    let decoder = JSONDecoder()
                    self.models = try decoder.decode([ModelConfig].self, from: data)
                    print("Models loaded on watch")
                } catch {
                    print("Error decoding models: \(error.localizedDescription)")
                }
            }

            // Handle start prediction
            if let data = message["startPrediction"] as? Data {
                do {
                    let decoder = JSONDecoder()
                    self.selectedModel = try decoder.decode(ModelConfig.self, from: data)
                    self.startPrediction()
                    print("Started prediction with model: \(self.selectedModel?.name ?? "")")
                } catch {
                    print("Error decoding model for prediction: \(error.localizedDescription)")
                }
            }

            // Handle stop prediction
            if message["stopPrediction"] as? Bool == true {
                self.stopPrediction()
                print("Stopped prediction")
            }
        }
        
        
        func performPrediction(with data: [CMAccelerometerData], model: ModelConfig) -> PredictionResult {
                // Preprocess data
                let features = Preprocessing.computeFeatures(from: data, config: model.config)

                // Convert features to MLMultiArray
                guard let inputArray = try? MLMultiArray(shape: [NSNumber(value: features.count)], dataType: .double) else {
                    fatalError("Could not create MLMultiArray")
                }

                for (index, value) in features.enumerated() {
                    inputArray[index] = NSNumber(value: value)
                }

                // Load the Core ML model
                guard let mlModel = loadModel(named: model.name) else {
                    fatalError("Could not load model \(model.name)")
                }

                // Create a prediction input
                let input = ModelInput(features: inputArray)

                // Perform prediction
                guard let predictionOutput = try? mlModel.prediction(from: input) else {
                    fatalError("Prediction failed")
                }

                // Extract prediction results
                let predictedCadence = predictionOutput.featureValue(for: "cadence")?.doubleValue ?? 0.0
                let predictedGear = Int(predictionOutput.featureValue(for: "gear")?.int64Value ?? 0)
                let predictedTerrain = predictionOutput.featureValue(for: "terrain")?.stringValue ?? "Unknown"
                let predictedPosition = (predictionOutput.featureValue(for: "isStanding")?.int64Value ?? 0) == 1

                return PredictionResult(
                    timestamp: Date(),
                    cadence: predictedCadence,
                    gear: predictedGear,
                    terrain: predictedTerrain,
                    isStanding: predictedPosition,
                    speed: currentSpeed
                )
            }

            func loadModel(named modelName: String) -> MLModel? {
                // Assuming models are included in the app bundle
                guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
                    print("Model \(modelName) not found")
                    return nil
                }

                do {
                    let compiledModel = try MLModel(contentsOf: modelURL)
                    return compiledModel
                } catch {
                    print("Error loading model \(modelName): \(error.localizedDescription)")
                    return nil
                }
            }
        
    }
    
    // Handle receiving data from the phone via transferUserInfo (if needed)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        // Implement if you need to receive data from the phone
    }
    
    // Handle receiving data from the phone via sendMessageData (if implemented)
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        // Implement if you need to receive data from the phone
    }
    
    // MARK: - HKWorkoutSessionDelegate Methods
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        // Handle state changes if needed
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate Methods
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Handle collected data if needed
    }
}
class ModelInput: MLFeatureProvider {
    var features: MLMultiArray

    var featureNames: Set<String> {
        return ["input"]
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "input" {
            return MLFeatureValue(multiArray: features)
        }
        return nil
    }

    init(features: MLMultiArray) {
        self.features = features
    }
}
