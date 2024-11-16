//
// ModelServer.swift
// CyclingCadenceApp
//
// Created by Jones, Liam on 11/6/24.

import Foundation
import MultipeerConnectivity
import CoreML

class ModelServer: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate {
    private let serviceType = "cyclingtrainer"
    private let peerID = MCPeerID(displayName: Host.current().localizedName ?? "Mac")
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private weak var viewModel: ModelTrainingViewModel?

    init(viewModel: ModelTrainingViewModel) {
        self.viewModel = viewModel
        super.init()
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .optional)
        session.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
    }

    func start() {
        advertiser.startAdvertisingPeer()
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        session.disconnect()
    }

    func sendModel(model: ModelConfig) {
        guard let compiledModelURL = getCompiledModelURL(modelName: model.name) else {
            print("Compiled model not found")
            return
        }

        do {
            let modelData = try Data(contentsOf: compiledModelURL)
            try session.send(modelData, toPeers: session.connectedPeers, with: .reliable)
            print("Model sent to peers")
        } catch {
            print("Error sending model: \(error.localizedDescription)")
        }
    }

    private func getCompiledModelURL(modelName: String) -> URL? {
        let fileManager = FileManager.default
        let documentsURL = getDocumentsDirectory()
        let modelURL = documentsURL.appendingPathComponent("\(modelName).mlmodel")
        guard let compiledModelURL = try? MLModel.compileModel(at: modelURL) else {
            return nil
        }
        return compiledModelURL
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - MCSessionDelegate Methods

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("Peer \(peerID.displayName) changed state: \(state.rawValue)")
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle data received from iOS app if needed
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    // MARK: - MCNearbyServiceAdvertiserDelegate Methods

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Failed to start advertising: \(error.localizedDescription)")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("Received invitation from \(peerID.displayName)")
        invitationHandler(true, session)
    }
}
