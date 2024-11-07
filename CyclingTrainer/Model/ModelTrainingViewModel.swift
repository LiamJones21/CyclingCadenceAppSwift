//
//  ModelTrainingViewModel.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


// ModelTrainingViewModel.swift
//
//import Foundation
//import SwiftUI
//import Combine
//import CreateML
//import MultipeerConnectivity
//import CoreML
//
//class ModelTrainingViewModel: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate {
//    @Published var sessions: [Session] = []
//    @Published var models: [ModelConfig] = []
//    @Published var trainingLogs: String = ""
//    @Published var trainingInProgress: Bool = false
//    @Published var trainingError: Double?
//    @Published var selectedSessions: Set<UUID> = []
//    @Published var bestAccuracy: Double?
//    @Published var bestHyperparameters: [String: Any] = [:]
//    @Published var connectedPeers: [MCPeerID] = []
//
//    // Networking properties
//    private let serviceType = "cycling-trainer"
//    private let myPeerID = MCPeerID(displayName: Host.current().localizedName ?? "Mac")
//    private var session: MCSession!
//    private var advertiser: MCNearbyServiceAdvertiser!
//
//    override init() {
//        super.init()
//        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
//        session.delegate = self
//        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
//        advertiser.delegate = self
//        advertiser.startAdvertisingPeer()
//        loadSessions()
//        loadModels()
//    }
//
//    deinit {
//        advertiser.stopAdvertisingPeer()
//        session.disconnect()
//    }
//
//    // Load sessions from local storage
//    func loadSessions() {
//        let fileURL = getDocumentsDirectory().appendingPathComponent("sessions.json")
//        if let data = try? Data(contentsOf: fileURL),
//           let loadedSessions = try? JSONDecoder().decode([Session].self, from: data) {
//            self.sessions = loadedSessions
//        }
//    }
//
//    func saveSessions() {
//        let fileURL = getDocumentsDirectory().appendingPathComponent("sessions.json")
//        if let data = try? JSONEncoder().encode(sessions) {
//            try? data.write(to: fileURL)
//        }
//    }
//
//    // Load models from local storage
//    func loadModels() {
//        let fileURL = getDocumentsDirectory().appendingPathComponent("models.json")
//        if let data = try? Data(contentsOf: fileURL),
//           let loadedModels = try? JSONDecoder().decode([ModelConfig].self, from: data) {
//            self.models = loadedModels
//        }
//    }
//
//    func saveModels() {
//        let fileURL = getDocumentsDirectory().appendingPathComponent("models.json")
//        if let data = try? JSONEncoder().encode(models) {
//            try? data.write(to: fileURL)
//        }
//    }
//
//    
//
//    // MARK: - Networking Methods
//
//    func sendMessage(message: [String: Any], to peerID: MCPeerID) {
//        do {
//            let data = try JSONSerialization.data(withJSONObject: message, options: [])
//            try session.send(data, toPeers: [peerID], with: .reliable)
//        } catch {
//            print("Error sending message: \(error)")
//        }
//    }
//
//    func sendModel(named modelName: String, to peerID: MCPeerID) {
//        let modelURL = getDocumentsDirectory().appendingPathComponent("\(modelName).mlmodel")
//        guard let modelData = try? Data(contentsOf: modelURL) else {
//            print("Model not found")
//            return
//        }
//
//        let message: [String: Any] = ["type": "modelData", "modelName": modelName]
//        sendMessage(message: message, to: peerID)
//
//        do {
//            try session.send(modelData, toPeers: [peerID], with: .reliable)
//        } catch {
//            print("Error sending model: \(error)")
//        }
//    }
//
//    func requestSessionsList(from peerID: MCPeerID) {
//        let message: [String: Any] = ["type": "requestSessionsList"]
//        sendMessage(message: message, to: peerID)
//    }
//
//    func handleReceivedSessionList(_ sessionList: [[String: Any]]) {
//        for sessionDict in sessionList {
//            if let session = Session.fromDictionary(sessionDict) {
//                if !self.sessions.contains(where: { $0.id == session.id }) {
//                    self.sessions.append(session)
//                }
//            }
//        }
//        saveSessions()
//    }
//
//    // MARK: - MCSessionDelegate Methods
//
//    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
//        DispatchQueue.main.async {
//            switch state {
//            case .connected:
//                self.connectedPeers.append(peerID)
//            case .notConnected:
//                self.connectedPeers.removeAll(where: { $0 == peerID })
//            default:
//                break
//            }
//        }
//    }
//
//    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
//        if let message = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
//           let type = message["type"] as? String {
//            switch type {
//            case "sessionList":
//                if let sessions = message["sessions"] as? [[String: Any]] {
//                    self.handleReceivedSessionList(sessions)
//                }
//            case "sessionData":
//                if let sessionData = message["data"] as? Data,
//                   let session = try? JSONDecoder().decode(Session.self, from: sessionData) {
//                    if (!self.sessions.contains(where: { $0.id == session.id })) {
//                        self.sessions.append(session)
//                        saveSessions()
//                    }
//                }
//            case "startTraining":
//                // Handle remote training request
//                DispatchQueue.main.async {
//                    self.handleRemoteTrainingRequest(message: message, from: peerID)
//                }
//            default:
//                break
//            }
//        } else {
//            // Handle other data if necessary
//        }
//    }
//
//    
//
//    // Other required delegate methods with empty implementations
//    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
//    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
//    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
//
//    // MARK: - MCNearbyServiceAdvertiserDelegate Methods
//
//    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
//        print("Failed to start advertising: \(error.localizedDescription)")
//    }
//
//    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
//        invitationHandler(true, session)
//    }
//
//    // Helper methods
//
//    func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}
// ViewModels/ModelTrainingViewModel.swift

import Foundation
import Combine
import MultipeerConnectivity
import CoreML

class ModelTrainingViewModel: NSObject, ObservableObject {
    @Published var sessions: [Session] = []
    @Published var models: [ModelConfig] = []
    @Published var trainingLogs: String = ""
    @Published var trainingInProgress: Bool = false
    @Published var trainingError: Double?
    @Published var selectedSessions: Set<UUID> = []
    @Published var bestAccuracy: Double?
    @Published var bestHyperparameters: [String: Any] = [:]
    @Published var connectedPeers: [MCPeerID] = []
    @Published var trainingSettings: [String: Any] = [:]      // For storing training parameters
    @Published var phoneSessions: [Session] = []             // Sessions received from the phone
    @Published var phoneModels: [ModelConfig] = []
    
    private let serviceType = "cyclingtrainer" // Must be <= 15 chars, lowercase
    private let myPeerID = MCPeerID(displayName: Host.current().localizedName ?? "Mac")
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    
    override init() {
        super.init()
        setupSession()
        setupAdvertiser()
        loadLocalSessions()
        loadLocalModels()
    }
    
    deinit {
        advertiser.stopAdvertisingPeer()
        session.disconnect()
    }
    
    // MARK: - Setup Methods
    
    private func setupSession() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }
    
    private func setupAdvertiser() {
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
    }
    
    // MARK: - Session and Model Management
        
        func loadLocalSessions() {
            let fileURL = getDocumentsDirectory().appendingPathComponent("sessions.json")
            if let data = try? Data(contentsOf: fileURL),
               let sessions = try? JSONDecoder().decode([Session].self, from: data) {
                self.sessions = sessions
            }
        }
        
        func saveLocalSessions() {
            let fileURL = getDocumentsDirectory().appendingPathComponent("sessions.json")
            if let data = try? JSONEncoder().encode(sessions) {
                try? data.write(to: fileURL)
            }
        }
        
        func loadLocalModels() {
            let fileURL = getDocumentsDirectory().appendingPathComponent("models.json")
            if let data = try? Data(contentsOf: fileURL),
               let models = try? JSONDecoder().decode([ModelConfig].self, from: data) {
                self.models = models
            }
        }
        
        func saveLocalModels() {
            let fileURL = getDocumentsDirectory().appendingPathComponent("models.json")
            if let data = try? JSONEncoder().encode(models) {
                try? data.write(to: fileURL)
            }
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
    func requestModel(modelName: String) {
            if let peerID = connectedPeers.first {
                let message: [String: Any] = ["type": "requestModel", "modelName": modelName]
                sendMessage(message: message, to: peerID)
            } else {
                print("No connected peers to send the request.")
            }
        }
    
    func sendModel(model: ModelConfig) {
        guard let modelURL = getCompiledModelURL(modelName: model.name) else {
            print("Compiled model not found for \(model.name)")
            return
        }
        
        do {
            let modelData = try Data(contentsOf: modelURL)
            let message: [String: Any] = ["type": "modelData", "modelName": model.name]
            sendMessage(message: message, to: session.connectedPeers.first!)
            try session.send(modelData, toPeers: session.connectedPeers, with: .reliable)
            print("Model \(model.name) sent successfully")
        } catch {
            print("Error sending model: \(error.localizedDescription)")
        }
    }
    
    private func getCompiledModelURL(modelName: String) -> URL? {
        let fileManager = FileManager.default
        let documentsURL = getDocumentsDirectory()
        let modelURL = documentsURL.appendingPathComponent("\(modelName).mlmodel")
        do {
            let compiledModelURL = try MLModel.compileModel(at: modelURL)
            return compiledModelURL
        } catch {
            print("Error compiling model \(modelName): \(error.localizedDescription)")
            return nil
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - MCSessionDelegate

extension ModelTrainingViewModel: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.connectedPeers.append(peerID)
                print("Connected to \(peerID.displayName)")
            case .notConnected:
                self.connectedPeers.removeAll(where: { $0 == peerID })
                print("Disconnected from \(peerID.displayName)")
            case .connecting:
                print("Connecting to \(peerID.displayName)")
            @unknown default:
                print("Unknown state for \(peerID.displayName)")
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle received data
        if let message = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let type = message["type"] as? String {
            switch type {
            case "trainingSettingsUpdate":
                if let parameters = message["parameters"] as? [String: Any] {
                    DispatchQueue.main.async {
                        self.trainingSettings = parameters
                        NotificationCenter.default.post(name: .openTrainingSettings, object: nil)
                    }
                }
            case "startTraining":
                if let parameters = message["parameters"] as? [String: Any] {
                    DispatchQueue.main.async {
                        self.trainingSettings = parameters
                        self.startTraining(with: parameters, from: peerID)
                    }
                }
            case "requestSessionsList":
                self.sendSessionsList(to: peerID)
            case "sessionList":
                if let sessionsArray = message["sessions"] as? [[String: Any]] {
                    let receivedSessions = sessionsArray.compactMap { Session.fromDictionary($0) }
                    DispatchQueue.main.async {
                        self.phoneSessions = receivedSessions
                    }
                }
            case "requestModel":
                if let modelName = message["modelName"] as? String {
                    if let model = self.models.first(where: { $0.name == modelName }) {
                        self.sendModel(model: model)
                    }
                }
            case "modelList":
                if let modelsArray = message["models"] as? [[String: Any]] {
                    let receivedModels = modelsArray.compactMap { dict -> ModelConfig? in
                        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
                              let model = try? JSONDecoder().decode(ModelConfig.self, from: data) else {
                            return nil
                        }
                        return model
                    }
                    DispatchQueue.main.async {
                        self.phoneModels = receivedModels
                    }
                }
            case "trainingLog":
                if let log = message["log"] as? String {
                    DispatchQueue.main.async {
                        self.trainingLogs.append(contentsOf: log + "\n")
                    }
                }
            case "trainingCompleted":
                if let bestAccuracy = message["bestAccuracy"] as? Double {
                    DispatchQueue.main.async {
                        self.trainingInProgress = false
                        self.bestAccuracy = bestAccuracy
                    }
                }
            default:
                break
            }
        } else {
            // Handle other data types if necessary
        }
    }
    
    // Implement other required delegate methods with empty implementations
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension ModelTrainingViewModel: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Failed to start advertising: \(error.localizedDescription)")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Automatically accept invitations
        invitationHandler(true, session)
    }
}

// MARK: - Additional Methods

extension ModelTrainingViewModel {
    func sendSessionsList(to peerID: MCPeerID) {
        let sessionList = sessions.map { $0.toDictionary() }
        let message: [String: Any] = ["type": "sessionList", "sessions": sessionList]
        sendMessage(message: message, to: peerID)
    }
    
    func requestSessionsFromPhone() {
        if let peerID = connectedPeers.first {
            let message: [String: Any] = ["type": "requestSessionsList"]
            sendMessage(message: message, to: peerID)
        }
    }
    
    func requestModelsFromPhone() {
        if let peerID = connectedPeers.first {
            let message: [String: Any] = ["type": "requestModelList"]
            sendMessage(message: message, to: peerID)
        }
    }
    
    func startTraining(with parameters: [String: Any], from peerID: MCPeerID) {
        guard let selectedSessionIDs = parameters["selectedSessionIDs"] as? [String] else { return }
        
        // Fetch sessions based on IDs
        let selectedSessions = sessions.filter { selectedSessionIDs.contains($0.id.uuidString) }
        
        // Proceed with preprocessing and training
        DispatchQueue.global(qos: .userInitiated).async {
            self.trainingInProgress = true
            
            // Simulate training process
            for i in 1...10 {
                Thread.sleep(forTimeInterval: 1)
                let logMessage = "Training progress: \(i * 10)%"
                DispatchQueue.main.async {
                    self.trainingLogs.append(logMessage + "\n")
                }
                let message: [String: Any] = ["type": "trainingLog", "log": logMessage]
                self.sendMessage(message: message, to: peerID)
            }
            // Training completed
            self.trainingInProgress = false
            self.bestAccuracy = Double.random(in: 0.0...1.0)
            let completionMessage: [String: Any] = ["type": "trainingCompleted", "bestAccuracy": self.bestAccuracy ?? 0.0]
            self.sendMessage(message: completionMessage, to: peerID)
        }
    }

    
    func handleRemoteTrainingRequest(message: [String: Any], from peerID: MCPeerID) {
        guard let parameters = message as? [String: Any],
              let selectedSessionIDs = parameters["selectedSessionIDs"] as? [String] else {
            return
        }

        let selectedSessions = sessions.filter { selectedSessionIDs.contains($0.id.uuidString) }
        // Extract other parameters and start training
        let windowSize = parameters["windowSize"] as? Int ?? 150
        let windowStep = parameters["windowStep"] as? Int ?? 75
        let modelTypes = parameters["modelTypes"] as? [String] ?? ["LightGBM"]
        let preprocessingTypes = parameters["preprocessingTypes"] as? [String] ?? ["None"]
        let filteringOptions = parameters["filteringOptions"] as? [String] ?? ["None"]
        let scalerOptions = parameters["scalerOptions"] as? [String] ?? ["None"]
        let usePCA = parameters["usePCA"] as? Bool ?? false
        let includeAcceleration = parameters["includeAcceleration"] as? Bool ?? true
        let includeRotationRate = parameters["includeRotationRate"] as? Bool ?? true
        let isAutomatic = parameters["isAutomatic"] as? Bool ?? false
        let maxTrainingTime = parameters["maxTrainingTime"] as? Double ?? 300

        self.trainModel(
            windowSize: windowSize,
            windowStep: windowStep,
            modelTypes: modelTypes,
            preprocessingTypes: preprocessingTypes,
            filteringOptions: filteringOptions,
            scalerOptions: scalerOptions,
            usePCA: usePCA,
            includeAcceleration: includeAcceleration,
            includeRotationRate: includeRotationRate,
            isAutomatic: isAutomatic,
            maxTrainingTime: maxTrainingTime,
            parametersToOptimize: [],
            selectedSessions: selectedSessions,
            logHandler: { log in
                DispatchQueue.main.async {
                    self.trainingLogs.append(contentsOf: log + "\n")
                    // Send log update to iPhone
                    let logMessage: [String: Any] = ["type": "trainingLog", "log": log]
                    self.sendMessage(message: logMessage, to: peerID)
                }
            },
            completion: { error in
                DispatchQueue.main.async {
                    self.trainingError = error
                    self.trainingInProgress = false
                    // Notify iPhone of training completion
                    let completionMessage: [String: Any] = ["type": "trainingCompleted", "bestAccuracy": error ?? 0.0]
                    self.sendMessage(message: completionMessage, to: peerID)
                }
            }
        )
    }
    // MARK: - Training Functionality

    func trainModel(
        windowSize: Int,
        windowStep: Int,
        modelTypes: [String],
        preprocessingTypes: [String],
        filteringOptions: [String],
        scalerOptions: [String],
        usePCA: Bool,
        includeAcceleration: Bool,
        includeRotationRate: Bool,
        isAutomatic: Bool,
        maxTrainingTime: Double,
        parametersToOptimize: [String],
        selectedSessions: [Session],
        logHandler: @escaping (String) -> Void,
        completion: @escaping (Double?) -> Void
    ) {
//        trainingInProgress = true
//        trainingLogs = ""
//        DispatchQueue.global(qos: .userInitiated).async {
//            let data: [Double] = selectedSessions.flatMap { $0.data.map { $0.value } }
//
//            let preprocessor = DataPreprocessor(
//                data: data,
//                windowSize: windowSize,
//                windowStep: windowStep,
//                preprocessingType: preprocessingTypes.first ?? "None",
//                filtering: filteringOptions.first ?? "None",
//                scaler: scalerOptions.first ?? "None",
//                usePCA: usePCA,
//                includeAcceleration: includeAcceleration,
//                includeRotationRate: includeRotationRate
//            )
//
//            // Ensure 'processedFeatures' is [String: [Double]]
//            let features: [String: [Double]] = preprocessor.processedFeatures
//
//            // Convert [String: [Double]] to [String: MLDataColumn<Double>]
//            var columns: [String: MLDataColumn<Double>] = [:]
//            for (key, values) in features {
//                columns[key] = MLDataColumn<Double>(values)
//            }
//
//            // Initialize the MLDataTable with the columns dictionary
//            guard let dataTable = try? MLDataTable(dictionary: columns) else {
//                DispatchQueue.main.async {
//                    self.trainingInProgress = false
//                    self.trainingLogs += "Failed to initialize MLDataTable with provided features.\n"
//                    completion(nil)
//                }
//                return
//            }
//
//            // Proceed with splitting the data and training the model
//            let (trainingData, testingData) = dataTable.randomSplit(by: 0.8, seed: 42)
//            let configuration = MLModelConfiguration()
//            configuration.computeUnits = .all
//
//            do {
//                let regressor = try MLRegressor(trainingData: trainingData, targetColumn: "target")
//                let evaluationMetrics = regressor.evaluation(on: testingData)
//                let error = evaluationMetrics.rootMeanSquaredError
//
//                DispatchQueue.main.async {
//                    self.trainingInProgress = false
//                    self.trainingError = error
//                    self.trainingLogs += "Training completed with RMSE: \(error)\n"
//                    self.bestAccuracy = error
//                    // Save model and update models list
//                    let modelName = "Model_\(Date().timeIntervalSince1970)"
//                    let modelURL = self.getDocumentsDirectory().appendingPathComponent("\(modelName).mlmodel")
//                    try? regressor.write(to: modelURL)
//                    let config = ModelConfig.Config(
//                        windowSize: windowSize,
//                        windowStep: windowStep,
//                        preprocessingType: preprocessingTypes.first ?? "None",
//                        filtering: filteringOptions.first ?? "None",
//                        scaler: scalerOptions.first ?? "None",
//                        usePCA: usePCA,
//                        includeAcceleration: includeAcceleration,
//                        includeRotationRate: includeRotationRate
//                    )
//                    let modelConfig = ModelConfig(id: UUID(), name: modelName, config: config)
//                    self.models.append(modelConfig)
//                    self.saveModels()
//                    completion(error)
//                }
//            } catch {
//                DispatchQueue.main.async {
//                    self.trainingInProgress = false
//                    self.trainingLogs += "Training failed: \(error.localizedDescription)\n"
//                    completion(nil)
//                }
//            }
//        }
    }
}
