//
//  PredictionView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 10/31/24.
//


// PredictionView.swift

import SwiftUI

struct PredictionView: View {
    @ObservedObject var viewModel: CyclingViewModel
    @State private var showModelPicker = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Prediction Mode")
                .font(.largeTitle)
                .padding()

            // Model Selection
            Button(action: {
                showModelPicker = true
            }) {
                Text(viewModel.selectedModelIndex != nil ? "Selected Model: \(viewModel.models[viewModel.selectedModelIndex!].name)" : "Select Model")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            .sheet(isPresented: $showModelPicker) {
                ModelPickerView(viewModel: viewModel)
            }

            // Load Models Button
            Button(action: {
                viewModel.sendModelsToWatch()
            }) {
                Text("Load Models to Watch")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(viewModel.isWatchConnected ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            .disabled(!viewModel.isWatchConnected)

            // Start/Stop Prediction
            Button(action: {
                if viewModel.isPredicting {
                    viewModel.stopPrediction()
                } else {
                    viewModel.startPrediction(selectedModelIndex: viewModel.selectedModelIndex)
                }
            }) {
                Text(viewModel.isPredicting ? "Stop Prediction" : "Start Prediction")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(viewModel.isPredicting ? Color.red : Color.gray)
                    .cornerRadius(50)
                    .foregroundColor(.white)
                    .padding(.horizontal)
            }
            .disabled(viewModel.selectedModelIndex == nil || !viewModel.isWatchConnected)

            Spacer()

            // Display Prediction Results
            if let predictionResult = viewModel.predictionResult {
                PredictionResultView(predictionResult: predictionResult)
            } else {
                Text("No Prediction Data")
                    .foregroundColor(.gray)
            }
        }
    }
}

struct PredictionResultView: View {
    let predictionResult: PredictionResult

    var body: some View {
        VStack(spacing: 10) {
            Text("Predicted Cadence: \(String(format: "%.0f RPM", predictionResult.cadence))")
                .font(.title2)
                .foregroundColor(.blue)
            Text("Predicted Gear: \(predictionResult.gear)")
                .font(.title2)
                .foregroundColor(.green)
            Text("Predicted Terrain: \(predictionResult.terrain)")
                .font(.title2)
                .foregroundColor(.orange)
            Text("Predicted Position: \(predictionResult.isStanding ? "Standing" : "Sitting")")
                .font(.title2)
                .foregroundColor(.purple)
            Text("Speed: \(String(format: "%.2f m/s", predictionResult.speed))")
                .font(.title2)
                .foregroundColor(.black)
        }
        .padding()
        .background(Color(UIColor.systemGray5))
        .cornerRadius(15)
        .padding(.horizontal)
    }
}
