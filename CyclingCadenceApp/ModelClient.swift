//
// ModelClient.swift
// CyclingCadenceApp
//
// Created by Jones, Liam on 11/6/24.

import Foundation
import MultipeerConnectivity
import CoreML

class ModelClient: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate {
    private let serviceType = "cyclingtrainer" // Ensure this matches the Mac's serviceType
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession!
    private var browser: MCNearbyServiceBrowser!
    @Published var connectedPeers: [MCPeerID] = []
    @Published var receivedModelURL: URL?

    override init() {
        super.init()
        setupSession()
        setupBrowser()
    }

    private func setupSession() {
        print("Setting up MCSession")
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .optional)
        session.delegate = self
    }

    private func setupBrowser() {
        print("Setting up MCNearbyServiceBrowser")
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
    }

    func requestModels() {
        if let peerID = connectedPeers.first {
            let message: [String: Any] = ["type": "requestModelList"]
            sendMessage(message: message, to: peerID)
            print("Requested models from \(peerID.displayName)")
        } else {
            print("No connected peers to request models from.")
        }
    }

    func sendMessage(message: [String: Any], to peerID: MCPeerID) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message, options: [])
            try session.send(data, toPeers: [peerID], with: .reliable)
            print("Sent message to \(peerID.displayName): \(message)")
        } catch {
            print("Error sending message: \(error)")
        }
    }

    func saveReceivedModel(data: Data, modelName: String) {
        let documentsURL = getDocumentsDirectory()
        let modelURL = documentsURL.appendingPathComponent("\(modelName).mlmodelc")
        do {
            try data.write(to: modelURL)
            receivedModelURL = modelURL
            print("Saved received model to \(modelURL)")
        } catch {
            print("Error saving model: \(error.localizedDescription)")
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - MCSessionDelegate Methods

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                print("Connected to \(peerID.displayName)")
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

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle received data
        print("Received data from \(peerID.displayName)")
        // Determine if data is a JSON message or model data
        if let message = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let type = message["type"] as? String {
            switch type {
            case "modelData":
                if let modelName = message["modelName"] as? String {
                    // Expecting the next data packet to be model data
                    // You might need a protocol to pair modelName with modelData
                    // For simplicity, assuming immediate model data after modelData message
                }
            default:
                print("Unknown message type: \(type)")
            }
        } else {
            // Assuming the data is model data
            let modelName = "ReceivedModel_\(Date().timeIntervalSince1970)"
            saveReceivedModel(data: data, modelName: modelName)
        }
    }

    // Required but not used
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
}
