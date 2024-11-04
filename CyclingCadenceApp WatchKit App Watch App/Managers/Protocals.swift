//
//  HealthKitManagerDelegate 2.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/3/24.
// Protocols.swift
// CyclingCadenceApp

import Foundation
import CoreMotion
import CoreLocation

protocol HealthKitManagerDelegate: AnyObject {
    func didStartWorkout()
    func didEndWorkout()
}

protocol SensorManagerDelegate: AnyObject {
    func didUpdateDeviceMotionData(_ data: CMDeviceMotion)
}

protocol ConnectivityManagerDelegate: AnyObject {
    func didUpdateConnectionStatus(isConnected: Bool)
    func didReceiveRecordingState(isRecording: Bool, timestamp: Date)
    func didReceiveMessage(_ message: [String: Any])
}

protocol PredictionManagerDelegate: AnyObject {
    func didReceivePredictionResult(_ result: PredictionResult)
}

protocol LocationManagerDelegate: AnyObject {
    func didUpdateLocation(_ location: CLLocation)
}

