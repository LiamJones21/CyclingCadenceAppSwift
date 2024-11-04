//
//  SensorManagerDelegate.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/3/24.
// SensorManager.swift
// CyclingCadenceApp

import Foundation
import CoreMotion



class SensorManager {
    private let motionManager = CMMotionManager()
    weak var delegate: SensorManagerDelegate?

    func setup() {
        // Configure motion manager if needed
    }

    func startSensors() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 50.0 // 50 Hz
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
                if let data = data {
                    self?.delegate?.didUpdateDeviceMotionData(data)
                }
            }
        }
    }

    func stopSensors() {
        motionManager.stopDeviceMotionUpdates()
    }
}
