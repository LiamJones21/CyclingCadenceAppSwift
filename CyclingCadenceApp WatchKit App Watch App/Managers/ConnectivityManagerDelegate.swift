//
//  ConnectivityManagerDelegate.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/3/24.
// ConnectivityManager.swift
// CyclingCadenceApp

import Foundation
import WatchConnectivity

// Import Protocols and Models
import CoreMotion
import CoreLocation

class ConnectivityManager: NSObject, WCSessionDelegate {
    weak var delegate: ConnectivityManagerDelegate?
    private var sessionWC: WCSession?

    func setup() {
        if WCSession.isSupported() {
            sessionWC = WCSession.default
            sessionWC?.delegate = self
            sessionWC?.activate()
        }
    }

    func sendRecordingState(isRecording: Bool, timestamp: Date) {
        if let session = sessionWC {
            let data: [String: Any] = [
                "isRecording": isRecording,
                "recordingStateLastChanged": timestamp.timeIntervalSince1970
            ]
            if session.isReachable {
                session.sendMessage(data, replyHandler: nil, errorHandler: { error in
                    print("Error sending recording state: \(error.localizedDescription)")
                })
            } else {
                session.transferUserInfo(data)
                print("Transferred recording state via UserInfo.")
            }
        }
    }

    func sendPredictionResult(_ result: PredictionResult) {
        if let session = sessionWC, session.isReachable {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(result)
                let message: [String: Any] = ["predictionResult": data]
                session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                    print("Error sending prediction result: \(error.localizedDescription)")
                })
            } catch {
                print("Error encoding prediction result: \(error.localizedDescription)")
            }
        }
    }

    func sendCollectedData(_ data: [CyclingData]) {
        if let session = sessionWC {
            do {
                let encoder = JSONEncoder()
                let encodedData = try encoder.encode(data)
                let userInfo: [String: Any] = ["cyclingData": encodedData]
                session.transferUserInfo(userInfo)
                print("Transferred collected data to phone via UserInfo.")
            } catch {
                print("Error encoding cycling data: \(error.localizedDescription)")
            }
        }
    }

    // WCSessionDelegate methods
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        delegate?.didUpdateConnectionStatus(isConnected: session.isReachable)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        delegate?.didUpdateConnectionStatus(isConnected: session.isReachable)
    }

    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
            delegate?.didReceiveMessage(message)
    }
}
