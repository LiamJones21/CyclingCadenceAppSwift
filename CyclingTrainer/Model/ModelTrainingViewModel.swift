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
import CreateML
import MultipeerConnectivity
import CoreML

class ModelTrainingViewModel: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate {
    @Published var sessions: [Session] = []
    @Published var models: [ModelConfig] = []
    @Published var trainingLogs: String = ""
    @Published var trainingInProgress: Bool = false
    @Published var trainingError: Double?
    @Published var selectedSessions: Set<UUID> = []
    @Published var bestAccuracy: Double?
    @Published var bestHyperparameters: [String: Any] = [:]
    @Published var connectedPeers: [MCPeerID] = []

    // Networking properties
    private let serviceType = "cycling-trainer"
    private let myPeerID = MCPeerID(displayName: Host.current().localizedName ?? "Mac")
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!

    override init() {
        super.init()
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        loadSessions()
        loadModels()
    }

    deinit {
        advertiser.stopAdvertisingPeer()
        session.disconnect()
    }

    // Load sessions from local storage
    func loadSessions() {
        let fileURL = getDocumentsDirectory().appendingPathComponent("sessions.json")
        if let data = try? Data(contentsOf: fileURL),
           let loadedSessions = try? JSONDecoder().decode([Session].self, from: data) {
            self.sessions = loadedSessions
        }
    }

    func saveSessions() {
        let fileURL = getDocumentsDirectory().appendingPathComponent("sessions.json")
        if let data = try? JSONEncoder().encode(sessions) {
            try? data.write(to: fileURL)
        }
    }

    // Load models from local storage
    func loadModels() {
        let fileURL = getDocumentsDirectory().appendingPathComponent("models.json")
        if let data = try? Data(contentsOf: fileURL),
           let loadedModels = try? JSONDecoder().decode([ModelConfig].self, from: data) {
            self.models = loadedModels
        }
    }

    func saveModels() {
        let fileURL = getDocumentsDirectory().appendingPathComponent("models.json")
        if let data = try? JSONEncoder().encode(models) {
            try? data.write(to: fileURL)
        }
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

    // MARK: - Networking Methods

    func sendMessage(message: [String: Any], to peerID: MCPeerID) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message, options: [])
            try session.send(data, toPeers: [peerID], with: .reliable)
        } catch {
            print("Error sending message: \(error)")
        }
    }

    func sendModel(named modelName: String, to peerID: MCPeerID) {
        let modelURL = getDocumentsDirectory().appendingPathComponent("\(modelName).mlmodel")
        guard let modelData = try? Data(contentsOf: modelURL) else {
            print("Model not found")
            return
        }

        let message: [String: Any] = ["type": "modelData", "modelName": modelName]
        sendMessage(message: message, to: peerID)

        do {
            try session.send(modelData, toPeers: [peerID], with: .reliable)
        } catch {
            print("Error sending model: \(error)")
        }
    }

    func requestSessionsList(from peerID: MCPeerID) {
        let message: [String: Any] = ["type": "requestSessionsList"]
        sendMessage(message: message, to: peerID)
    }

    func handleReceivedSessionList(_ sessionList: [[String: Any]]) {
        for sessionDict in sessionList {
            if let session = Session.fromDictionary(sessionDict) {
                if !self.sessions.contains(where: { $0.id == session.id }) {
                    self.sessions.append(session)
                }
            }
        }
        saveSessions()
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
            case "sessionList":
                if let sessions = message["sessions"] as? [[String: Any]] {
                    self.handleReceivedSessionList(sessions)
                }
            case "sessionData":
                if let sessionData = message["data"] as? Data,
                   let session = try? JSONDecoder().decode(Session.self, from: sessionData) {
                    if (!self.sessions.contains(where: { $0.id == session.id })) {
                        self.sessions.append(session)
                        saveSessions()
                    }
                }
            case "startTraining":
                // Handle remote training request
                DispatchQueue.main.async {
                    self.handleRemoteTrainingRequest(message: message, from: peerID)
                }
            default:
                break
            }
        } else {
            // Handle other data if necessary
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

    // Other required delegate methods with empty implementations
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    // MARK: - MCNearbyServiceAdvertiserDelegate Methods

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Failed to start advertising: \(error.localizedDescription)")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    // Helper methods

    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
