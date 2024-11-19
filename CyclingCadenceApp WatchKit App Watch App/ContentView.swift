//
//  ContentView.swift
//  CyclingCadenceApp WatchKit App Watch App
//
//  Created by Jones, Liam on 20/10/2024.
// ContentView.swift

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = WatchViewModel()
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                HStack {
                    Text("GPS: \(viewModel.GPSSpeedEstimate)m/s")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)

                    Divider()

                    Text("Acc: \(viewModel.GPSSpeedEstimateAccuracy)m")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                // Center-aligned session duration
                HStack {
                    Text(viewModel.sessionDuration)
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)

                    Divider()

                    Text("Data Count: \(viewModel.dataPointCount)")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // Speed display
                Text(String(format: "%.2f m/s", viewModel.currentSpeed))
                    .font(.system(size: 36, weight: .bold))

                // Icons for position and terrain
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isStanding ? "figure.stand" : "figure.walk")
                        .font(.system(size: 20))
                    Image(systemName: viewModel.currentTerrain.lowercased() == "road" ? "road.lanes" : "leaf")
                        .font(.system(size: 20))
                }

                // Cadence, Data, and Gear displays in a single row
                HStack(alignment: .top, spacing: 15) {
                    // Cadence display
                    VStack {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.system(size: 20))
                        Text("\(Int(viewModel.estimateCadence() ?? 0))/min")
                            .font(.system(size: 16))
                    }

                    // Accelerometer data display
                    VStack {
                        Text("Data")
                            .font(.system(size: 10)) // Reduced size
                        Text(String(format: "X: %.2f", viewModel.accelerometerDataSaved?.acceleration.x ?? 0.0))
                            .font(.system(size: 9))
                        Text(String(format: "Y: %.2f", viewModel.accelerometerDataSaved?.acceleration.y ?? 0.0))
                            .font(.system(size: 9))
                        Text(String(format: "Z: %.2f", viewModel.accelerometerDataSaved?.acceleration.z ?? 0.0))
                            .font(.system(size: 9))
                    }
                    .padding(.vertical, 2)

                    // Gear display
                    VStack {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                        Text("\(viewModel.currentGear)")
                            .font(.system(size: 16))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 0)

                // Connection status
                withAnimation(.easeInOut(duration: 0.5)) {
                    Text(viewModel.isPhoneConnected ? "Connected" : "Not Connected")
                        .font(.system(size: 14))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(viewModel.isPhoneConnected ? Color.green : Color.red)
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .padding(.top, 5)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.5), value: viewModel.isPhoneConnected)
                }

                // Display model name during prediction
                if viewModel.isPredicting, let modelName = viewModel.selectedModel?.name {
                    Text("Model: \(modelName)")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }

                // Start/Stop Button
                Button(action: {
                    if viewModel.isPredicting {
//                        viewModel.stopPrediction()
                    } else if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.startRecording()
                    }
                }) {
                    Text(viewModel.isPredicting ? "Stop Prediction" : (viewModel.isRecording ? "Stop Recording" : "Start Recording"))
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(viewModel.isPredicting ? Color.red : (viewModel.isRecording ? Color.orange : Color.green))
                        .cornerRadius(50)
                        .foregroundColor(.white)
                }
                .padding(.top, 10)
            }
            .padding()
            .onAppear {
                viewModel.setup()
            }
            // Long-press gesture to show settings
            .onLongPressGesture {
                showSettings = true
            }
            // Present the SettingsView when showSettings is true
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(viewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}


