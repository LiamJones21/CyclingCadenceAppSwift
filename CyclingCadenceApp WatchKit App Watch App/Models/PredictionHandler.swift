//
//  PredictionHandler.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 06/12/2024.
//


import Foundation
import CoreML

class PredictionHandler {
    private var accelX: [Double] = []
    private var accelY: [Double] = []
    private var accelZ: [Double] = []
    private var rotX: [Double] = []
    private var rotY: [Double] = []
    private var rotZ: [Double] = []
    private var speedArray: [Double] = []

    // Window size must match what the model expects (e.g., 100)
    private let windowSize = 100 

    func reset() {
        accelX.removeAll()
        accelY.removeAll()
        accelZ.removeAll()
        rotX.removeAll()
        rotY.removeAll()
        rotZ.removeAll()
        speedArray.removeAll()
    }

    func addDataPoint(accel_x: Double, accel_y: Double, accel_z: Double,
                      rotacc_x: Double, rotacc_y: Double, rotacc_z: Double,
                      speed: Double) {
        accelX.append(accel_x)
        accelY.append(accel_y)
        accelZ.append(accel_z)
        rotX.append(rotacc_x)
        rotY.append(rotacc_y)
        rotZ.append(rotacc_z)
        speedArray.append(speed)
        // If arrays exceed windowSize, trim the oldest data
        if accelX.count > windowSize {
            accelX.removeFirst()
            accelY.removeFirst()
            accelZ.removeFirst()
            rotX.removeFirst()
            rotY.removeFirst()
            rotZ.removeFirst()
            speedArray.removeFirst()
        }
    }

    func isReadyForPrediction() -> Bool {
        return accelX.count == windowSize
    }

    func runPrediction() -> PredictionResult? {
        guard isReadyForPrediction() else { return nil }

        // Prepare input for CoreML model
        // Feature order: accel_x, accel_y, accel_z, rotacc_x, rotacc_y, rotacc_z, speed
        let featureCount = 7
        let inputArray = try! MLMultiArray(shape: [1, NSNumber(value: windowSize), NSNumber(value: featureCount)], dataType: .double)
        for i in 0..<windowSize {
            inputArray[[0, i, 0] as [NSNumber]] = NSNumber(value: accelX[i])
            inputArray[[0, i, 1] as [NSNumber]] = NSNumber(value: accelY[i])
            inputArray[[0, i, 2] as [NSNumber]] = NSNumber(value: accelZ[i])
            inputArray[[0, i, 3] as [NSNumber]] = NSNumber(value: rotX[i])
            inputArray[[0, i, 4] as [NSNumber]] = NSNumber(value: rotY[i])
            inputArray[[0, i, 5] as [NSNumber]] = NSNumber(value: rotZ[i])
            inputArray[[0, i, 6] as [NSNumber]] = NSNumber(value: speedArray[i])
        }

        // Run the model
        guard let modelURL = Bundle.main.url(forResource: "CyclingPredictor", withExtension: "mlpackage"),
              let compiledModelURL = try? MLModel.compileModel(at: modelURL),
              let model = try? MLModel(contentsOf: compiledModelURL)
        else { return nil }

        let inputValue = MLFeatureValue(multiArray: inputArray)
        let inputDict: [String: MLFeatureValue] = ["accelerometer_input": inputValue]
        let provider = try! MLDictionaryFeatureProvider(dictionary: inputDict)
        guard let prediction = try? model.prediction(from: provider) else { return nil }

        // Assuming model outputs:
        // cadence_output: Double
        // terrain_output: Multi-class (we pick argmax)
        // stance_output: Multi-class (we pick argmax)

        let predictedCadence = prediction.featureValue(for: "cadence_output")?.doubleValue ?? 0.0

        // Terrain and stance are categorical outputs
        // Suppose we have their probabilities or logits:
        guard let terrainOutput = prediction.featureValue(for: "terrain_output")?.dictionaryValue,
              let stanceOutput = prediction.featureValue(for: "stance_output")?.dictionaryValue else {
            return nil
        }

        // Find terrain with highest probability
        let predictedTerrain = terrainOutput.max(by: { $0.value.doubleValue < $1.value.doubleValue })?.key ?? "Road"
        let predictedStanceIndex = stanceOutput.max(by: { $0.value.doubleValue < $1.value.doubleValue })?.key ?? "0"
        let predictedStance = (predictedStanceIndex == "1") // Assuming "1" = standing, "0" = seated

        return PredictionResult(
            timestamp: Date(),
            cadence: predictedCadence,
            gear: 0, // Will be computed after calling runPrediction
            terrain: predictedTerrain,
            isStanding: predictedStance,
            speed: speedArray.last ?? 0.0
        )
    }
}