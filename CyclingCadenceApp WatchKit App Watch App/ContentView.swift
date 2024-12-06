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

                HStack {
                    Text(viewModel.sessionDuration)
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)

                    Divider()

                    Text("Data: \(viewModel.dataPointCount)")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Text(String(format: "%.2f m/s", viewModel.currentSpeed))
                    .font(.system(size: 36, weight: .bold))

                HStack(spacing: 4) {
                    Image(systemName: viewModel.isStanding ? "figure.stand" : "figure.walk")
                        .font(.system(size: 20))
                    Image(systemName: viewModel.currentTerrain.lowercased() == "road" ? "road.lanes" : "leaf")
                        .font(.system(size: 20))
                }

                HStack(alignment: .top, spacing: 15) {
                    VStack {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.system(size: 20))
                        Text("\(Int(viewModel.estimateCadence() ?? 0))/min")
                            .font(.system(size: 16))
                    }

                    VStack {
                        Text("Data")
                            .font(.system(size: 10))
                        Text(String(format: "X: %.2f", viewModel.accelerometerData?.userAcceleration.x ?? 0.0))
                            .font(.system(size: 9))
                        Text(String(format: "Y: %.2f", viewModel.accelerometerData?.userAcceleration.y ?? 0.0))
                            .font(.system(size: 9))
                        Text(String(format: "Z: %.2f", viewModel.accelerometerData?.userAcceleration.z ?? 0.0))
                            .font(.system(size: 9))
                    }
                    .padding(.vertical, 2)

                    VStack {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                        Text("\(viewModel.currentGear)")
                            .font(.system(size: 16))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 0)

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

                // Show predicted values if in prediction mode
                if viewModel.isPredicting {
                    VStack(spacing: 5) {
                        Text("Predicted Cadence: \(Int(viewModel.predictedCadence)) RPM")
                            .foregroundColor(.blue)
                        Text("Predicted Terrain: \(viewModel.predictedTerrain)")
                            .foregroundColor(.blue)
                        Text("Predicted Stance: \(viewModel.predictedStance ? "Standing" : "Seated")")
                            .foregroundColor(.blue)
                        Text("Predicted Gear: \(viewModel.predictedGear)")
                            .foregroundColor(.blue)
                    }
                }

                // Buttons for control
                HStack {
                    Button(action: {
                        if viewModel.isPredicting {
                            viewModel.stopPredictionMode()
                        } else {
                            viewModel.startPredictionMode()
                        }
                    }) {
                        Text(viewModel.isPredicting ? "Stop Predict" : "Start Predict")
                            .font(.system(size: 14, weight: .bold))
                            .padding()
                            .background(viewModel.isPredicting ? Color.red : Color.blue)
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }

                    Button(action: {
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        } else {
                            viewModel.startRecording()
                        }
                    }) {
                        Text(viewModel.isRecording ? "Stop Rec" : "Start Rec")
                            .font(.system(size: 14, weight: .bold))
                            .padding()
                            .background(viewModel.isRecording ? Color.orange : Color.green)
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                }

            }
            .padding()
            .onAppear {
                viewModel.setup()
            }
            .onLongPressGesture {
                showSettings = true
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(viewModel)
            }
        }
    }
}
