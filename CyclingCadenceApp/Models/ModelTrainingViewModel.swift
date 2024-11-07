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
        
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        loadSessions()
        loadModels()
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
                self.connectedPeers.append(peerID)
            case .notConnected:
                self.connectedPeers.removeAll(where: { $0 == peerID })
            default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let type = message["type"] as? String {
            switch type {
            case "requestSessionsList":
                self.sendSessionsList(to: peerID)
            case "trainingLog":
                if let log = message["log"] as? String {
                    self.handleReceivedTrainingLog(log)
                }
            case "trainingCompleted":
                self.handleTrainingCompleted(message: message)
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
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    
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
    
    // Helper methods
    
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
