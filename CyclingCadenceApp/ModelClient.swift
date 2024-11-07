//
//  ModelClient.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


import Foundation
import MultipeerConnectivity

class ModelClient: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate {
    private let serviceType = "cycling-model"
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession!
    private var browser: MCNearbyServiceBrowser!
//    @Published var availableModels: [ModelInfo] = []
    @Published var receivedModelURL: URL?

    override init() {
        super.init()
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
    }

    func requestModels() {
        // Send a request to the server for available models
    }

    func saveReceivedModel(data: Data, modelName: String) {
        let documentsURL = getDocumentsDirectory()
        let modelURL = documentsURL.appendingPathComponent("\(modelName).mlmodelc")
        do {
            try data.write(to: modelURL)
            DispatchQueue.main.async {
                self.receivedModelURL = modelURL
            }
        } catch {
            print("Error saving model: \(error.localizedDescription)")
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - MCSessionDelegate Methods

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("Peer \(peerID.displayName) changed state: \(state.rawValue)")
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle received model data
        let modelName = "ReceivedModel_\(Date().timeIntervalSince1970)"
        saveReceivedModel(data: data, modelName: modelName)
    }

    // Other required delegate methods with empty implementations

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
}
