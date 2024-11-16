//
//  ModelTrainingViewModel.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//

// ModelTrainingViewModel.swift
import Foundation
import SwiftUI
import Combine
import MultipeerConnectivity
import CoreML

class ModelTrainingViewModel: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate {
    
    @Published var sessions: [Session] = []
    @Published var models: [ModelConfig] = []
    @Published var trainingLogs: String = ""
    @Published var trainingInProgress: Bool = false
    @Published var trainingError: Double?
    @Published var selectedSessions: Set<UUID> = []
    @Published var bestAccuracy: Double?
    @Published var connectedPeers: [MCPeerID] = []
    
    @Published var trainingSettings = TrainingSettings(
        windowSizes: [],
        windowSteps: [],
        modelTypes: [],
        preprocessingTypes: [],
        filteringOptions: [],
        scalerOptions: [],
        usePCA: false,
        includeAcceleration: true,
        includeRotationRate: true,
        isAutomatic: false,
        maxTrainingTime: 300,
        selectedSessionIDs: []
    )
    
    private var cancellables = Set<AnyCancellable>()
    
    // **Add cyclingViewModel as a property**
    private let cyclingViewModel: CyclingViewModel
    
    // Networking properties
    private let serviceType = "cyclingtrainer"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession!
    private var browser: MCNearbyServiceBrowser!
    
    // Initialize with CyclingViewModel
    init(cyclingViewModel: CyclingViewModel) {
        // **Assign the passed cyclingViewModel to the property**
        self.cyclingViewModel = cyclingViewModel
        self.sessions = cyclingViewModel.sessions

        super.init()

        // Observe changes in cyclingViewModel.sessions
        cyclingViewModel.$sessions
            .sink { [weak self] updatedSessions in
                self?.sessions = updatedSessions
            }
            .store(in: &cancellables)

        $trainingSettings
            .removeDuplicates()  // Avoid sending updates if the values haven't actually changed
            .sink { [weak self] updatedSettings in
                self?.sendUpdatedSettingsToMac(updatedSettings)
            }
            .store(in: &cancellables)

        setupSession()
//        setupBrowser()
        loadSessions()
        loadModels()
    }

    private func setupSession() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    private func setupBrowser() {
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
    }
    
    deinit {
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    // Load sessions from CyclingViewModel
    func loadSessions() {
        self.sessions = cyclingViewModel.sessions
    }
    
    func saveSessions() {
        cyclingViewModel.sessions = self.sessions
    }
    
    // Load models from CyclingViewModel
    func loadModels() {
        self.models = cyclingViewModel.models
    }
    
    func saveModels() {
        cyclingViewModel.models = self.models
    }
    
    // MARK: - Networking Methods
    
    func sendMessage(message: [String: Any], to peerID: MCPeerID) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message, options: [])
            try session.send(data, toPeers: [peerID], with: .reliable)
        } catch {
            print("Error sending message: \(error)")
        }
    }
    
    func sendSessionsList(to peerID: MCPeerID) {
        let sessionList = sessions.map { $0.toDictionary() }
        let message: [String: Any] = ["type": "sessionList", "sessions": sessionList]
        sendMessage(message: message, to: peerID)
    }
    
    func sendSessionData(sessionID: UUID, to peerID: MCPeerID) {
        if let session = sessions.first(where: { $0.id == sessionID }) {
            if let data = try? JSONEncoder().encode(session) {
                let message: [String: Any] = ["type": "sessionData", "data": data]
                sendMessage(message: message, to: peerID)
            }
        }
    }
    
    func handleReceivedTrainingLog(_ log: String) {
        DispatchQueue.main.async {
            self.trainingLogs.append(contentsOf: log + "\n")
        }
    }
    
    func handleTrainingCompleted(message: [String: Any]) {
        DispatchQueue.main.async {
            self.trainingInProgress = false
            self.trainingError = message["bestAccuracy"] as? Double
        }
    }
    
    // MARK: - MCSessionDelegate Methods
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
            DispatchQueue.main.async {
                switch state {
                case .connected:
                    if !self.connectedPeers.contains(peerID) {
                        self.connectedPeers.append(peerID)
                        print("Connected to \(peerID.displayName)")
                    }
                case .notConnected:
                    self.connectedPeers.removeAll { $0 == peerID }
                    print("Disconnected from \(peerID.displayName)")
                case .connecting:
                    print("Connecting to \(peerID.displayName)")
                @unknown default:
                    print("Unknown state for \(peerID.displayName)")
                }
            }
        }

    func requestModel(modelName: String) {
        if let peerID = connectedPeers.first {
            let message: [String: Any] = ["type": "requestModel", "modelName": modelName]
            sendMessage(message: message, to: peerID)
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle received data
        print("Received data from \(peerID.displayName)")
        if let message = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let type = message["type"] as? String {
            switch type {
            case "trainingSettingsUpdate":
                if let parameters = message["parameters"] as? [String: Any],
                   let newSettings = TrainingSettings(from: parameters) { // Use initializer here
                    DispatchQueue.main.async {
                        self.trainingSettings = newSettings
//                        NotificationCenter.default.post(name: .openTrainingSettings, object: nil)
                    }
                }
            case "startTraining":
                if let parameters = message["parameters"] as? [String: Any],
                   let newSettings = TrainingSettings(from: parameters) { // Use initializer here
                    DispatchQueue.main.async {
                        self.trainingSettings = newSettings
                        self.startTraining(withParameters: parameters, from: peerID)
                    }
                }
            case "sessionList":
                if let sessionsArray = message["sessions"] as? [[String: Any]] {
                    let receivedSessions = sessionsArray.compactMap { Session.fromDictionary($0) }
                    DispatchQueue.main.async {
                        self.sessions = receivedSessions
                        self.saveSessions()
                        print("Received and updated sessions from \(peerID.displayName)")
                    }
                }
            case "trainingLog":
                if let log = message["log"] as? String {
                    self.handleReceivedTrainingLog(log)
                }
            case "trainingCompleted":
                if let bestAccuracy = message["bestAccuracy"] as? Double {
                    self.handleTrainingCompleted(message: message)
                }
            case "modelData":
                if let modelName = message["modelName"] as? String {
                    // Expecting the next data packet to be model data
                    // Handle accordingly if needed
                }
            default:
                break
            }
        } else {
            // Assuming the data is model data
            if let modelName = "ReceivedModel_\(Date().timeIntervalSince1970)" as String? {
                self.handleReceivedModel(data: data, modelName: modelName)
            }
        }
    }
    
    func handleReceivedModel(data: Data, modelName: String) {
        let modelURL = getDocumentsDirectory().appendingPathComponent("\(modelName).mlmodel")
        do {
            try data.write(to: modelURL)
            // Compile the model
            let compiledModelURL = try MLModel.compileModel(at: modelURL)
            // Save the model info
            DispatchQueue.main.async {
                let config = ModelConfig.Config(
                    windowSize: 0,
                    windowStep: 0,
                    preprocessingType: "",
                    filtering: "",
                    scaler: "",
                    usePCA: false,
                    includeAcceleration: false,
                    includeRotationRate: false
                )
                let modelConfig = ModelConfig(id: UUID(), name: modelName, config: config)
                self.models.append(modelConfig)
                self.saveModels()
            }
        } catch {
            print("Error saving or compiling model: \(error)")
        }
    }
    
    // Empty implementations for required delegate methods
    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    
    // MARK: - MCNearbyServiceBrowserDelegate Methods
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Failed to start browsing: \(error.localizedDescription)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("Found peer: \(peerID.displayName)")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Lost peer: \(peerID.displayName)")
    }
    
    // MARK: - Helper Methods
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func sendUpdatedSettingsToMac(_ settings: TrainingSettings) {
        let parameters: [String: Any] = [
            "windowSizes": settings.windowSizes.map { Int($0 * 50) },
            "windowSteps": settings.windowSteps.map { Int($0 * 50) },
            "modelTypes": Array(settings.modelTypes),
            "preprocessingTypes": Array(settings.preprocessingTypes),
            "filteringOptions": Array(settings.filteringOptions),
            "scalerOptions": Array(settings.scalerOptions),
            "usePCA": settings.usePCA,
            "includeAcceleration": settings.includeAcceleration,
            "includeRotationRate": settings.includeRotationRate,
            "isAutomatic": settings.isAutomatic,
            "maxTrainingTime": settings.maxTrainingTime,
            "selectedSessionIDs": settings.selectedSessionIDs.map { $0.uuidString }
        ]
        
        if let peerID = connectedPeers.first {
            let message: [String: Any] = ["type": "trainingSettingsUpdate", "parameters": parameters]
            sendMessage(message: message, to: peerID)
            print("Sent training settings to \(peerID.displayName)")
        }
    }

    func startTraining(withParameters parameters: [String: Any], from peerID: MCPeerID) {
        // Set training in progress to true and clear logs
        trainingInProgress = true
        trainingLogs = ""

        // Send training request to connected Mac (if any)
        if let peerID = connectedPeers.first {
            let message: [String: Any] = ["type": "startTraining", "parameters": parameters]
            sendMessage(message: message, to: peerID)
            print("Sent start training request to \(peerID.displayName)")
        }
    }
}
