//
//  CyclingViewModel.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.

import Foundation
import CoreMotion
import CoreLocation
import WatchConnectivity
import Combine
import SwiftUI
import CreateML

// MARK: - Activity Log Entry
struct ActivityLogEntry: Identifiable, Codable {
    var id = UUID()
    var timestamp: Date
    var message: String
    var sessionDate: Date?
    var logType: LogType

    // Conform LogType to CaseIterable and Identifiable
    enum LogType: String, Codable, CaseIterable, Identifiable {
        case watchStart = "Watch Start"
        case watchStop = "Watch Stop"
        case phoneStart = "Phone Start"
        case phoneStop = "Phone Stop"
        case disconnected = "Disconnected"
        case connected = "Connected"
        case savedBatch = "Saved Batch"
        case sessionCreated = "Session Created"
        
        var id: String { self.rawValue }
    }
}

// MARK: - Phone Data Model
struct PhoneData: Codable {
    let timestamp: Date
    let gear: Int
    let terrain: String
    let isStanding: Bool
}

// MARK: - Prediction Result Model

struct PredictionResult: Codable, Identifiable {
    var id = UUID()
    var timestamp: Date
    var cadence: Double
    var gear: Int
    var terrain: String
    var isStanding: Bool
    var speed: Double
}

class CyclingViewModel: NSObject, ObservableObject, CLLocationManagerDelegate, WCSessionDelegate {
    // MARK: - Published Properties
    @Published var currentSpeed: Double = 0.0 // Speed in m/s
    @Published var currentGear: Int = 1 {
        didSet {
            sendSettingsToWatch()
            recordPhoneDataChange()
        }
    }
    @Published var currentTerrain: String = "Road" {
        didSet {
            sendSettingsToWatch()
            recordPhoneDataChange()
        }
    }
    @Published var isStanding: Bool = false {
        didSet {
            sendSettingsToWatch()
            recordPhoneDataChange()
        }
    }
    @Published var gearRatios: [String] = []
    @Published var sessions: [Session] = []
    @Published var isRecording: Bool = false
    @Published var latestSession: Session?
    @Published var isWatchConnected: Bool = false
    @Published var activityLog: [ActivityLogEntry] = [] // Activity log
    @Published var recordingStateLastChanged: Date = Date()
    

    // MARK: - Properties
    private var motionManager = CMMotionManager()
    private var locationManager = CLLocationManager()
    private var sessionWC = WCSession.default

    // Data Collection
    private var currentSession: Session?

    // Settings
    var wheelCircumference: Double = 2.1 // Default value in meters

    // Hybrid Speed Calculation
    private var gpsSpeed: Double = 0.0
    private var sensorSpeed: Double = 0.0
    private var lastUpdateTime: TimeInterval = Date().timeIntervalSince1970

    // Low-pass filter for accelerometer data
    private var filteredAcceleration: Double = 0.0
    private let filterFactor: Double = 0.1

    private var hybridSpeed: Double {
        let gpsSpeedAvailable = gpsSpeed > 0.5 // Threshold for considering GPS speed reliable (0.5 m/s)

        let gpsWeight: Double = gpsSpeedAvailable ? 0.8 : 0.0
        let sensorWeight: Double = gpsSpeedAvailable ? 0.2 : 1.0

        return (gpsSpeed * gpsWeight) + (sensorSpeed * sensorWeight)
    }

    // Phone Data Changes with Timestamps
    private var phoneDataChanges: [PhoneData] = []

    // Data Batch Tracking
    private var dataBatchSaveCount: Int = 0
    private var totalDataPointsSaved: Int = 0
    
    // MARK: - Prediction Mode Properties
    @Published var isPredicting: Bool = false
    @Published var predictionResult: PredictionResult?
    @Published var models: [ModelConfig] = []
    @Published var selectedModelIndex: Int?

    // MARK: - Setup Methods
    func setup() {
        setupLocationManager()
        setupMotionManager()
        setupWatchConnectivity()
        loadSessionsFromFile()
        loadSettings()
        loadModels()
        loadActivityLogFromFile()
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }

    // MARK: - Application Lifecycle
    @objc func appWillResignActive() {
        saveSessionsToFile()
        saveActivityLogToFile()
    }

    // MARK: - Location Manager Setup
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - Motion Manager Setup for Sensor Fusion
    func setupMotionManager() {
        motionManager.accelerometerUpdateInterval = 1.0 / 50.0
        motionManager.startAccelerometerUpdates()

        Timer.scheduledTimer(withTimeInterval: 1.0 / 50.0, repeats: true) { [weak self] _ in
            if let accelData = self?.motionManager.accelerometerData {
                self?.updateSpeedFromSensorData(accelData: accelData)
            }
        }
    }
    // MARK: - Model Loading
        func loadModels() {
            // Load models from local storage or server
            // For simplicity, we will create dummy models
            models = [
                ModelConfig(name: "Model A", config: ModelConfig.Config(windowSize: 100, windowStep: 50, includeFFT: true, includeWavelet: false)),
                ModelConfig(name: "Model B", config: ModelConfig.Config(windowSize: 200, windowStep: 100, includeFFT: false, includeWavelet: true)),
                // Add more models as needed
            ]
        }
    
    // MARK: - Model Training
//    func trainModel(windowSize: Int, windowStep: Int, includeFFT: Bool, includeWavelet: Bool, modelType: String, maxTrainingTime: TimeInterval, completion: @escaping (Double?) -> Void) {
//        DispatchQueue.global(qos: .userInitiated).async {
//            // Load collected data
//            guard let data = self.loadTrainingData() else {
//                DispatchQueue.main.async {
//                    completion(nil)
//                }
//                return
//            }
//
//            // Preprocess data
//            let features = self.preprocessData(data: data, windowSize: windowSize, windowStep: windowStep, includeFFT: includeFFT, includeWavelet: includeWavelet)
//
//            // Create MLDataTable
//            guard let dataTable = try? MLDataTable(dictionary: features) else {
//                DispatchQueue.main.async {
//                    completion(nil)
//                }
//                return
//            }
//
//            // Split data
//            let (trainingData, testingData) = dataTable.randomSplit(by: 0.8, seed: 42)
//
//            // Set up training configuration
//            let configuration = MLModelConfiguration()
//            configuration.computeUnits = .cpuOnly
//
//            let startTime = Date()
//            var model: MLRegressor?
//
//            // Train model based on type
//            switch modelType {
//            case "Decision Tree":
//                let parameters = MLDecisionTreeRegressor.ModelParameters()
//                // Configure parameters if needed
//                model = try? MLDecisionTreeRegressor(trainingData: trainingData, targetColumn: "cadence", parameters: parameters, configuration: configuration)
//            case "Random Forest":
//                let parameters = MLRandomForestRegressor.ModelParameters()
//                // Configure parameters if needed
//                model = try? MLRandomForestRegressor(trainingData: trainingData, targetColumn: "cadence", parameters: parameters, configuration: configuration)
//            case "Linear Regression":
//                model = try? MLLinearRegressor(trainingData: trainingData, targetColumn: "cadence", configuration: configuration)
//            default:
//                print("Unsupported model type: \(modelType)")
//            }
//
//            // Check training duration
//            let trainingDuration = Date().timeIntervalSince(startTime)
//            if trainingDuration > maxTrainingTime {
//                DispatchQueue.main.async {
//                    print("Training exceeded maximum duration.")
//                    completion(nil)
//                }
//                return
//            }
//
//            // Evaluate model
//            if let model = model {
//                let evaluationMetrics = model.evaluation(on: testingData)
//                let error = evaluationMetrics.metrics[.rootMeanSquaredError] as? Double ?? 0.0
//
//                print("Training Error (RMSE): \(error)")
//
//                // Save model
//                let modelName = "CustomModel_\(Date().timeIntervalSince1970)"
//                let saveURL = self.getDocumentsDirectory().appendingPathComponent("\(modelName).mlmodel")
//                do {
//                    try model.write(to: saveURL)
//                } catch {
//                    print("Error saving model: \(error.localizedDescription)")
//                    DispatchQueue.main.async {
//                        completion(nil)
//                    }
//                    return
//                }
//
//                // Save model config as JSON
//                let configURL = self.getDocumentsDirectory().appendingPathComponent("\(modelName).json")
//                do {
//                    let encoder = JSONEncoder()
//                    let configData = try encoder.encode(ModelConfig.Config(windowSize: windowSize, windowStep: windowStep, includeFFT: includeFFT, includeWavelet: includeWavelet))
//                    try configData.write(to: configURL)
//                } catch {
//                    print("Error saving model config: \(error.localizedDescription)")
//                }
//
//                // Update models list
//                let config = ModelConfig.Config(windowSize: windowSize, windowStep: windowStep, includeFFT: includeFFT, includeWavelet: includeWavelet)
//                let newModel = ModelConfig(name: modelName, config: config)
//                DispatchQueue.main.async {
//                    self.models.append(newModel)
//                    completion(error)
//                }
//            } else {
//                DispatchQueue.main.async {
//                    print("Model training is not available on this device.")
//                    completion(nil)
//                }
//            }
//        }
//    }


        func loadTrainingData() -> [CyclingData]? {
            // Load your collected cycling data
            // Return an array of CyclingData
            // Implement this function based on your data storage
            return sessions.flatMap { $0.data }
        }

        func preprocessData(data: [CyclingData], windowSize: Int, windowStep: Int, includeFFT: Bool, includeWavelet: Bool) -> [String: [MLDataValueConvertible]] {
            var features: [String: [MLDataValueConvertible]] = [:]

            // Initialize feature arrays
            var meanAccelX: [Double] = []
            var meanAccelY: [Double] = []
            var meanAccelZ: [Double] = []
            var speed: [Double] = []
            var cadence: [Double] = []
            var terrain: [String] = []
            var isStanding: [Bool] = []

            // Process data into windows
            for start in stride(from: 0, to: data.count - windowSize, by: windowStep) {
                let end = start + windowSize
                let window = Array(data[start..<end])

                // Extract features
                let featureValues = extractFeatures(window: window, includeFFT: includeFFT, includeWavelet: includeWavelet)

                meanAccelX.append(featureValues.meanAccelX)
                meanAccelY.append(featureValues.meanAccelY)
                meanAccelZ.append(featureValues.meanAccelZ)
                speed.append(featureValues.meanSpeed)
                cadence.append(featureValues.meanCadence)
                terrain.append(featureValues.modeTerrain)
                isStanding.append(featureValues.modeIsStanding)
            }

            // Assign feature arrays to the dictionary
            features["meanAccelX"] = meanAccelX
            features["meanAccelY"] = meanAccelY
            features["meanAccelZ"] = meanAccelZ
            features["speed"] = speed
            features["cadence"] = cadence
            features["terrain"] = terrain
            features["isStanding"] = isStanding

            return features
        }
        
        func extractFeatures(window: [CyclingData], includeFFT: Bool, includeWavelet: Bool) -> (meanAccelX: Double, meanAccelY: Double, meanAccelZ: Double, meanSpeed: Double, meanCadence: Double, modeTerrain: String, modeIsStanding: Bool) {
            let accelX = window.map { $0.accelerometerData.x }
            let accelY = window.map { $0.accelerometerData.y }
            let accelZ = window.map { $0.accelerometerData.z }

            let meanAccelX = accelX.reduce(0, +) / Double(accelX.count)
            let meanAccelY = accelY.reduce(0, +) / Double(accelY.count)
            let meanAccelZ = accelZ.reduce(0, +) / Double(accelZ.count)
            let meanSpeed = window.map { $0.speed }.reduce(0, +) / Double(window.count)
            let meanCadence = window.map { $0.cadence }.reduce(0, +) / Double(window.count)

            let terrainCounts = Dictionary(grouping: window.map { $0.terrain }, by: { $0 }).mapValues { $0.count }
            let modeTerrain = terrainCounts.max(by: { $0.value < $1.value })?.key ?? "Unknown"

            let isStandingCounts = Dictionary(grouping: window.map { $0.isStanding }, by: { $0 }).mapValues { $0.count }
            let modeIsStanding = isStandingCounts.max(by: { $0.value < $1.value })?.key ?? false

            // Additional features can be calculated here, including FFT and Wavelet transforms, if implemented.

            return (meanAccelX, meanAccelY, meanAccelZ, meanSpeed, meanCadence, modeTerrain, modeIsStanding)
        }
        func preprocessData(data: [CyclingData], windowSize: Int, windowStep: Int, includeFFT: Bool, includeWavelet: Bool) -> [String: [Any]] {
            // Implement preprocessing steps similar to those in Preprocessing.swift
            // Return a dictionary where keys are column names and values are arrays of column data
            var features: [String: [Any]] = [:]
            // Implement your preprocessing logic here
            return features
        }

        func getDocumentsDirectory() -> URL {
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
    // MARK: - Model Management
        func addModel(from url: URL) {
            // Get model name
            let modelName = url.deletingPathExtension().lastPathComponent

            // Read the associated config file (assuming it's a JSON file with the same name)
            let configURL = url.deletingPathExtension().appendingPathExtension("json")
            do {
                let configData = try Data(contentsOf: configURL)
                let decoder = JSONDecoder()
                let config = try decoder.decode(ModelConfig.Config.self, from: configData)
                let newModel = ModelConfig(name: modelName, config: config)
                models.append(newModel)
                // Save models if needed
            } catch {
                print("Error loading model config: \(error.localizedDescription)")
            }
        }

        func removeModel(at index: Int) {
            models.remove(at: index)
            // Save models if needed
        }

        func deleteModels(at offsets: IndexSet) {
            models.remove(atOffsets: offsets)
            // Save models if needed
        }
    // MARK: - Prediction Control
        func startPrediction(selectedModelIndex: Int?) {
            guard let index = selectedModelIndex else { return }
            let model = models[index]
            isPredicting = true
            sendStartPredictionToWatch(model: model)
        }

        func stopPrediction() {
            isPredicting = false
            sendStopPredictionToWatch()
        }

        // MARK: - Watch Communication for Prediction
        func sendModelsToWatch() {
            if sessionWC.isReachable {
                do {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(models)
                    let dataDict: [String: Any] = ["models": data]
                    sessionWC.sendMessage(dataDict, replyHandler: nil, errorHandler: { error in
                        print("Error sending models to watch: \(error.localizedDescription)")
                    })
                    print("Sent models to watch")
                } catch {
                    print("Error encoding models: \(error.localizedDescription)")
                }
            } else {
                print("Watch is not reachable")
            }
        }

        func sendStartPredictionToWatch(model: ModelConfig) {
            if sessionWC.isReachable {
                do {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(model)
                    let dataDict: [String: Any] = ["startPrediction": data]
                    sessionWC.sendMessage(dataDict, replyHandler: nil, errorHandler: { error in
                        print("Error sending start prediction to watch: \(error.localizedDescription)")
                    })
                    print("Sent start prediction command to watch")
                } catch {
                    print("Error encoding model: \(error.localizedDescription)")
                }
            } else {
                print("Watch is not reachable")
            }
        }

        func sendStopPredictionToWatch() {
            if sessionWC.isReachable {
                let dataDict: [String: Any] = ["stopPrediction": true]
                sessionWC.sendMessage(dataDict, replyHandler: nil, errorHandler: { error in
                    print("Error sending stop prediction to watch: \(error.localizedDescription)")
                })
                print("Sent stop prediction command to watch")
            } else {
                print("Watch is not reachable")
            }
        }

      
    // MARK: - Save Settings Methods
        func saveWheelDiameter(_ diameter: Double) {
            let defaults = UserDefaults.standard
            defaults.setValue(diameter, forKey: "wheelDiameter")
            
            // Update wheelCircumference based on diameter
            let circumference = Double.pi * diameter
            defaults.setValue(circumference, forKey: "wheelCircumference")
        }

        func saveGearRatios() {
            let defaults = UserDefaults.standard
            defaults.setValue(gearRatios, forKey: "gearRatios")
        }
    
    
    // MARK: - GPS Speed Calculation
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let speed = locations.last?.speed, locations.last?.horizontalAccuracy ?? 100 > 0 {
            gpsSpeed = max(0, speed) // Speed in m/s from GPS
            DispatchQueue.main.async {
                self.currentSpeed = self.hybridSpeed
            }
        }
    }

    // MARK: - Sensor-based Speed Calculation (using accelerometer)
    func updateSpeedFromSensorData(accelData: CMAccelerometerData) {
        // Calculate the magnitude of the acceleration vector
        let accelerationMagnitude = sqrt(pow(accelData.acceleration.x, 2) +
                                         pow(accelData.acceleration.y, 2) +
                                         pow(accelData.acceleration.z, 2)) - 1.0 // Subtract gravity

        // Apply low-pass filter
        filteredAcceleration = (filterFactor * accelerationMagnitude) + ((1 - filterFactor) * filteredAcceleration)

        // Estimate speed changes based on filtered acceleration
        let currentTime = Date().timeIntervalSince1970
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        sensorSpeed += filteredAcceleration * deltaTime * 9.81 // Convert to m/s^2 and integrate to get speed

        // Apply damping to prevent drift
        sensorSpeed *= 0.9

        DispatchQueue.main.async {
            self.currentSpeed = self.hybridSpeed
        }
    }

    // MARK: - Estimate Cadence
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

    // MARK: - Recording Management
    func startRecording(synchronized: Bool = true) {
        isRecording = true
        recordingStateLastChanged = Date()
        currentSession = Session(date: Date(), data: [])
        sessions.append(currentSession!)
        recordPhoneDataChange() // Record initial state
        if synchronized {
            if isWatchConnected {
                sendRecordingStateToWatch()
            }
            // If not connected, the watch will update upon reconnection
        }
        sendSettingsToWatch()
        addActivityLog(message: "Recording started on phone at \(formatTime(Date()))", sessionDate: currentSession?.date, logType: .phoneStart)
    }

    func stopRecording(synchronized: Bool = true) {
        isRecording = false
        recordingStateLastChanged = Date()
        if synchronized {
            if isWatchConnected {
                sendRecordingStateToWatch()
            }
            // If not connected, the watch will update upon reconnection
        }
        sendSettingsToWatch()
        saveSessionsToFile()
        addActivityLog(message: "Recording stopped on phone at \(formatTime(Date()))", sessionDate: currentSession?.date, logType: .phoneStop)

        // Log any remaining data batches
        if dataBatchSaveCount > 0 {
            let sessionDate = currentSession?.dateFormatted ?? "Unknown Session"
            addActivityLog(message: "Saved \(totalDataPointsSaved) data points in \(dataBatchSaveCount) batches to session \(sessionDate) at \(formatTime(Date()))", sessionDate: currentSession?.date, logType: .savedBatch)
        }

        // Reset batch counts
        dataBatchSaveCount = 0
        totalDataPointsSaved = 0
    }

    // MARK: - Synchronization with Watch
    func sendRecordingStateToWatch() {
        if sessionWC.isReachable {
            let data: [String: Any] = [
                "isRecording": isRecording,
                "recordingStateLastChanged": recordingStateLastChanged.timeIntervalSince1970
            ]
            sessionWC.sendMessage(data, replyHandler: nil, errorHandler: { error in
                print("Error sending recording state to watch: \(error.localizedDescription)")
            })
            print("Sent recording state (\(isRecording)) to watch")
        } else {
            print("Watch is not reachable")
        }
    }

    func requestRecordingStateFromWatch() {
        if sessionWC.isReachable {
            let data: [String: Any] = ["request": "recordingState"]
            sessionWC.sendMessage(data, replyHandler: nil, errorHandler: { error in
                print("Error requesting recording state from watch: \(error.localizedDescription)")
            })
            print("Requested recording state from watch")
        } else {
            print("Watch is not reachable")
        }
    }

    func requestDataFromWatch() {
        if sessionWC.isReachable {
            let data: [String: Any] = ["request": "unsentData"]
            sessionWC.sendMessage(data, replyHandler: nil, errorHandler: { error in
                print("Error requesting unsent data from watch: \(error.localizedDescription)")
            })
            print("Requested unsent data from watch")
            addActivityLog(message: "Requested unsent data from watch at \(formatTime(Date()))", sessionDate: currentSession?.date, logType: .connected)
        } else {
            print("Watch is not reachable")
        }
    }

    func sendSettingsToWatch() {
        if sessionWC.isReachable {
            let data: [String: Any] = [
                "currentGear": currentGear,
                "currentTerrain": currentTerrain,
                "isStanding": isStanding,
                "gearRatios": gearRatios,
                "wheelCircumference": wheelCircumference
            ]
            sessionWC.sendMessage(data, replyHandler: nil, errorHandler: { error in
                print("Error sending settings to watch: \(error.localizedDescription)")
            })
            print("Sent settings to watch")
        } else {
            print("Watch is not reachable")
        }
    }

    // MARK: - Data Storage
    func storeData(cyclingDataArray: [CyclingData]) {
        if currentSession == nil {
            // Create a new session since we weren't recording
            currentSession = Session(date: Date(), data: [])
            sessions.append(currentSession!)
            addActivityLog(message: "Session created from received data at \(formatTime(Date()))", sessionDate: currentSession?.date, logType: .sessionCreated)
        }

        guard let currentSession = currentSession else { return }
        if let sessionIndex = sessions.firstIndex(where: { $0.id == currentSession.id }) {
            // Merge phone data changes with cycling data
            let mergedData = mergeData(cyclingDataArray: cyclingDataArray)
            sessions[sessionIndex].data.append(contentsOf: mergedData)
            saveSessionsToFile()
            print("Stored data to session. Data count: \(mergedData.count)")

            // Update UI only when recording has stopped
            if !isRecording {
                DispatchQueue.main.async {
                    self.latestSession = self.sessions[sessionIndex]
                }
            }

            // Increment batch count and total data points
            dataBatchSaveCount += 1
            totalDataPointsSaved += mergedData.count

            // Log data synchronization every N batches
            let logInterval = 5 // Adjust as needed
            if dataBatchSaveCount % logInterval == 0 {
                let sessionDate = currentSession.dateFormatted
                addActivityLog(message: "Saved \(totalDataPointsSaved) data points in \(dataBatchSaveCount) batches to session \(sessionDate) as of \(formatTime(Date()))", sessionDate: currentSession.date, logType: .savedBatch)
                // Reset counters after logging
                dataBatchSaveCount = 0
                totalDataPointsSaved = 0
            }
        }
    }

    func saveSessionsToFile() {
        let fileName = "SessionsData.json"
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = documentsDirectory.appendingPathComponent(fileName)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL)
            print("Sessions saved to \(fileURL)")
        } catch {
            print("Error saving sessions: \(error)")
        }
    }

    func loadSessionsFromFile() {
        let fileName = "SessionsData.json"
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = documentsDirectory.appendingPathComponent(fileName)

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            sessions = try decoder.decode([Session].self, from: data)
            print("Sessions loaded from \(fileURL)")
        } catch {
            print("Error loading sessions: \(error)")
        }
    }

    // MARK: - Activity Log Management
    func addActivityLog(message: String, sessionDate: Date?, logType: ActivityLogEntry.LogType) {
        let logEntry = ActivityLogEntry(timestamp: Date(), message: message, sessionDate: sessionDate, logType: logType)
        activityLog.append(logEntry)
        saveActivityLogToFile()
    }

    func clearActivityLog() {
        activityLog.removeAll()
        saveActivityLogToFile()
    }

    func saveActivityLogToFile() {
        let fileName = "ActivityLog.json"
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = documentsDirectory.appendingPathComponent(fileName)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(activityLog)
            try data.write(to: fileURL)
            print("Activity log saved to \(fileURL)")
        } catch {
            print("Error saving activity log: \(error)")
        }
    }

    func loadActivityLogFromFile() {
        let fileName = "ActivityLog.json"
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = documentsDirectory.appendingPathComponent(fileName)

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            activityLog = try decoder.decode([ActivityLogEntry].self, from: data)
            print("Activity log loaded from \(fileURL)")
        } catch {
            print("Error loading activity log: \(error)")
        }
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Settings Management
    func loadSettings() {
        let defaults = UserDefaults.standard
        wheelCircumference = defaults.double(forKey: "wheelCircumference")
        if wheelCircumference == 0 { wheelCircumference = 2.1 } // Default value

        if let savedRatios = defaults.array(forKey: "gearRatios") as? [String] {
            gearRatios = savedRatios
        }
    }

    // MARK: - Session Management
    func deleteSession(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        saveSessionsToFile()
    }

    // MARK: - WCSessionDelegate Methods
    func setupWatchConnectivity() {
        if WCSession.isSupported() {
            sessionWC.delegate = self
            sessionWC.activate()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        sessionWC.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            let previousState = self.isWatchConnected
            self.isWatchConnected = session.isReachable
            print("Watch connection status changed: \(self.isWatchConnected)")

            let timestamp = Date()
            if self.isWatchConnected != previousState {
                let status = self.isWatchConnected ? "connected" : "disconnected"
                let logType: ActivityLogEntry.LogType = self.isWatchConnected ? .connected : .disconnected
                self.addActivityLog(message: "Watch and Phone \(status) at \(self.formatTime(timestamp))", sessionDate: nil, logType: logType)
            }

            if self.isWatchConnected {
                // Request any unsent data from the watch
                self.requestDataFromWatch()

                // Synchronize recording state
                self.sendRecordingStateToWatch()
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = session.isReachable

            // Request recording state from watch upon activation
            self.sendRecordingStateToWatch()
        }
    }

    // Handle receiving messages from the watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let request = message["request"] as? String {
                if request == "recordingState" {
                    // Respond with current recording state
                    self.sendRecordingStateToWatch()
                } else if request == "unsentData" {
                    // Do nothing, as the watch should send data via transferUserInfo
                }
            } else {
                // Update recording state
                if let isRecordingFromWatch = message["isRecording"] as? Bool,
                   let recordingStateLastChangedFromWatch = message["recordingStateLastChanged"] as? TimeInterval {

                    let watchRecordingStateLastChanged = Date(timeIntervalSince1970: recordingStateLastChangedFromWatch)

                    if watchRecordingStateLastChanged > self.recordingStateLastChanged {
                        // The watch's recording state change is more recent
                        if self.isRecording != isRecordingFromWatch {
                            self.isRecording = isRecordingFromWatch
                            self.recordingStateLastChanged = watchRecordingStateLastChanged
                            print("Recording state updated from watch: \(isRecordingFromWatch)")

                            if isRecordingFromWatch {
                                self.startRecording(synchronized: false)
                                self.addActivityLog(message: "Watch started recording at \(self.formatTime(Date())). Starting recording on phone.", sessionDate: self.currentSession?.date, logType: .watchStart)
                            } else {
                                self.stopRecording(synchronized: false)
                                self.addActivityLog(message: "Watch stopped recording at \(self.formatTime(Date())). Stopping recording on phone.", sessionDate: self.currentSession?.date, logType: .watchStop)
                            }
                        }
                    } else if watchRecordingStateLastChanged < self.recordingStateLastChanged {
                        // Our recording state change is more recent, send it to the watch
                        self.sendRecordingStateToWatch()
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

                if settingsUpdated {
                    print("Settings updated from watch")
                }
            }
            if let data = message["predictionResult"] as? Data {
                do {
                    let decoder = JSONDecoder()
                    let prediction = try decoder.decode(PredictionResult.self, from: data)
                    self.predictionResult = prediction
                    print("Received prediction result from watch")
                } catch {
                    print("Error decoding prediction result: \(error.localizedDescription)")
                }
            }
        }
    }

    // Handle receiving data from the watch via transferUserInfo
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            if let data = userInfo["cyclingData"] as? Data {
                do {
                    let decoder = JSONDecoder()
                    let cyclingDataArray = try decoder.decode([CyclingData].self, from: data)
                    self.storeData(cyclingDataArray: cyclingDataArray)
                    print("Received cycling data from watch via UserInfo. Data count: \(cyclingDataArray.count)")
                } catch {
                    print("Error decoding cycling data from watch: \(error.localizedDescription)")
                }
            }
        }
    }

    // Handle receiving data from the watch via sendMessageData (if any)
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        DispatchQueue.main.async {
            do {
                let decoder = JSONDecoder()
                let cyclingDataArray = try decoder.decode([CyclingData].self, from: messageData)
                self.storeData(cyclingDataArray: cyclingDataArray)
                print("Received cycling data from watch. Data count: \(cyclingDataArray.count)")

                if let currentSession = self.currentSession {
                    // Update UI only when recording has stopped
                    if !self.isRecording {
                        self.latestSession = currentSession
                    }
                }
            } catch {
                print("Error decoding cycling data from watch: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Phone Data Recording
    func recordPhoneDataChange() {
        let phoneData = PhoneData(
            timestamp: Date(),
            gear: currentGear,
            terrain: currentTerrain,
            isStanding: isStanding
        )
        phoneDataChanges.append(phoneData)

        // Optional: Limit the size of phoneDataChanges to prevent memory issues
        if phoneDataChanges.count > 10000 {
            phoneDataChanges.removeFirst(phoneDataChanges.count - 10000)
        }
    }

    // MARK: - Data Merging
    func mergeData(cyclingDataArray: [CyclingData]) -> [CyclingData] {
        var mergedData: [CyclingData] = []
        var phoneDataIndex = 0

        for cyclingData in cyclingDataArray {
            var updatedCyclingData = cyclingData

            // Update settings based on phone data changes
            while phoneDataIndex < phoneDataChanges.count &&
                    phoneDataChanges[phoneDataIndex].timestamp <= cyclingData.timestamp {
                phoneDataIndex += 1
            }

            if phoneDataIndex > 0 {
                let lastPhoneData = phoneDataChanges[phoneDataIndex - 1]
                updatedCyclingData.gear = lastPhoneData.gear
                updatedCyclingData.terrain = lastPhoneData.terrain
                updatedCyclingData.isStanding = lastPhoneData.isStanding
            } else {
                // If no phone data changes are before the cycling data timestamp, use current settings
                updatedCyclingData.gear = currentGear
                updatedCyclingData.terrain = currentTerrain
                updatedCyclingData.isStanding = isStanding
            }

            mergedData.append(updatedCyclingData)
        }

        return mergedData
    }
}
// MARK: - Session Extension for Date Formatting
extension Session {
    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
