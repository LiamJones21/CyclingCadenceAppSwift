//
//  PredictionManagerDelegate.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/3/24.
// PredictionManager.swift
// CyclingCadenceApp

import Foundation
import CoreMotion

class PredictionManager {
    weak var delegate: PredictionManagerDelegate?
    var predictionStartTime: Date?
    var selectedModel: ModelConfig?
    private var motionManager = CMMotionManager()
    private var predictionTimer: Timer?
    private var predictionWindowData: [CMAccelerometerData] = []

    func startPrediction() {
        guard let model = selectedModel else { return }
        predictionStartTime = Date()
        predictionWindowData.removeAll()
        startSensorUpdatesForPrediction()
    }

    func stopPrediction() {
        predictionStartTime = nil
        stopSensorUpdatesForPrediction()
        selectedModel = nil
    }

    private func startSensorUpdatesForPrediction() {
        motionManager.accelerometerUpdateInterval = 1.0 / 50.0 // 50 Hz
        motionManager.startAccelerometerUpdates()

        predictionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 50.0, repeats: true) { [weak self] _ in
            if let accelData = self?.motionManager.accelerometerData {
                self?.handlePredictionSensorData(accelData: accelData)
            }
        }
    }

    private func stopSensorUpdatesForPrediction() {
        motionManager.stopAccelerometerUpdates()
        predictionTimer?.invalidate()
        predictionTimer = nil
    }

    private func handlePredictionSensorData(accelData: CMAccelerometerData) {
        guard let model = selectedModel else { return }

        predictionWindowData.append(accelData)

        // Check if we have enough data for a window
        if predictionWindowData.count >= model.config.windowSize {
            // Perform prediction
            let predictionResult = performPrediction(with: predictionWindowData, model: model)
            // Notify delegate
            delegate?.didReceivePredictionResult(predictionResult)
            // Remove data based on window step (overlap)
            predictionWindowData.removeFirst(model.config.windowStep)
        }
    }

    private func performPrediction(with data: [CMAccelerometerData], model: ModelConfig) -> PredictionResult {
        // Placeholder implementation
        // Perform preprocessing and prediction using the model and config
        // For now, we will simulate prediction results

        let randomCadence = Double.random(in: 60...120)
        let randomGear = Int.random(in: 1...5)
        let randomTerrain = ["Road", "Gravel"].randomElement()!
        let randomPosition = Bool.random()

        return PredictionResult(
            timestamp: Date(),
            cadence: randomCadence,
            gear: randomGear,
            terrain: randomTerrain,
            isStanding: randomPosition,
            speed: 0.0 // Update with actual speed if available
        )
    }
}
