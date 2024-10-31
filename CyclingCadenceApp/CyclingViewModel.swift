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

    // MARK: - Setup Methods
    func setup() {
        setupLocationManager()
        setupMotionManager()
        setupWatchConnectivity()
        loadSessionsFromFile()
        loadSettings()
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
