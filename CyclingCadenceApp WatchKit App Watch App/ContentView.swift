//
//  ContentView.swift
//  CyclingCadenceApp WatchKit App Watch App
//
//  Created by Jones, Liam on 20/10/2024.
// ContentView.swift (Apple Watch App)

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = WatchViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Display speed
                Text(String(format: "Speed: %.2f m/s", viewModel.currentSpeed))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)

                // Display cadence
                if let cadence = viewModel.estimateCadence() {
                    Text(String(format: "Cadence: %.0f RPM", cadence))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                }

                // Display data point count
                Text("Data Points: \(viewModel.dataPointCount)")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)

                // Display settings received indicator
                if viewModel.settingsReceived {
                    Text("Settings Updated")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                } else {
                    Text("Waiting for Settings")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }

                // Display bike configuration
                Text("Gear: \(viewModel.currentGear)")
                    .font(.system(size: 14))
                Text("Terrain: \(viewModel.currentTerrain)")
                    .font(.system(size: 14))
                Text(viewModel.isStanding ? "Standing" : "Sitting")
                    .font(.system(size: 14))

                // Display accelerometer data
                if let accelData = viewModel.accelerometerData {
                    Text(String(format: "Accel X: %.2f", accelData.acceleration.x))
                    Text(String(format: "Accel Y: %.2f", accelData.acceleration.y))
                    Text(String(format: "Accel Z: %.2f", accelData.acceleration.z))
                }

                // Connection status panel
                Text(viewModel.isPhoneConnected ? "Phone Connected" : "Phone Not Connected")
                    .foregroundColor(viewModel.isPhoneConnected ? .green : .red)
                    .padding(.bottom, 10)

                // Start/Stop recording button
                Button(action: {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.startRecording()
                    }
                }) {
                    Text(viewModel.isRecording ? "Stop Recording" : "Start Recording")
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(viewModel.isRecording ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .onAppear {
            viewModel.setup()
        }
    }
}
#Preview {
    ContentView()
}
