//
//  ContentView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = CyclingViewModel()
    @State private var showSessionDetail = false
    @State private var latestSession: Session?

    var body: some View {
        NavigationView {
            VStack {
                TabView {
                    // Home Tab
                    VStack(spacing: 20) {
                        InfoBox(viewModel: viewModel)
                        GearSelector(viewModel: viewModel)
                        TerrainAndStandSelector(viewModel: viewModel)
                        Spacer()
                        // Connection status panel
                        Text(viewModel.isWatchConnected ? "Watch Connected" : "Watch Not Connected")
                            .foregroundColor(viewModel.isWatchConnected ? .green : .red)
                            .padding()

                        RecordingControls(viewModel: viewModel)
                    }
                    .tabItem {
                        Image(systemName: "bicycle")
                        Text("Home")
                    }
                    .onAppear {
                        viewModel.setup()
                    }
                    PredictionView(viewModel: viewModel)
                                            .tabItem {
                                                Image(systemName: "waveform.path.ecg")
                                                Text("Prediction")
                                            }
                    // Settings Tab
                    SettingsView(viewModel: viewModel, modelTrainingViewModel: ModelTrainingViewModel(cyclingViewModel: CyclingViewModel()))
                        .tabItem {
                            Image(systemName: "gearshape")
                            Text("Settings")
                        }
                    // Data Tab
                    DataView(viewModel: viewModel)
                        .tabItem {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Data")
                        }
                }
                .navigationTitle("Cycling Cadence App")
                .navigationBarTitleDisplayMode(.inline)
                .onReceive(viewModel.$latestSession) { session in
                    if let session = session {
                        self.latestSession = session
                        self.showSessionDetail = true
                    }
                }
                .navigationDestination(isPresented: $showSessionDetail) {
                    if let session = latestSession {
                        SessionDetailView(session: session)
                    } else {
                        EmptyView()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

struct InfoBox: View {
    @ObservedObject var viewModel: CyclingViewModel

    var body: some View {
        VStack(spacing: 10) {
            Text(String(format: "%.2f m/s", viewModel.currentSpeed))
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.black)

            HStack {
                Text("Gear: \(viewModel.currentGear)")
                Spacer()
                Text("Terrain: \(viewModel.currentTerrain)")
                Spacer()
                Text(viewModel.isStanding ? "Standing" : "Sitting")
            }
            .font(.headline)
            .padding([.leading, .trailing], 20)

            // Display Cadence Estimate
            if let cadence = viewModel.estimateCadence() {
                Text("Estimated Cadence: \(String(format: "%.0f RPM", cadence))")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray5))
        .cornerRadius(15)
        .padding(.top, 20)
        .padding([.leading, .trailing], 20)
    }
}



struct TerrainAndStandSelector: View {
    @ObservedObject var viewModel: CyclingViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Select Terrain:")
                .font(.headline)

            HStack(spacing: 20) {
                ForEach(["Road", "Gravel"], id: \.self) { terrain in
                    Button(action: {
                        viewModel.currentTerrain = terrain
                    }) {
                        Text(terrain)
                            .frame(width: 120, height: 60)
                            .background(viewModel.currentTerrain == terrain ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }

            // Stand/Sit Selector
            Button(action: {
                viewModel.isStanding.toggle()
            }) {
                Text(viewModel.isStanding ? "Standing" : "Sitting")
                    .frame(width: 200, height: 60)
                    .background(viewModel.isStanding ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}

struct RecordingControls: View {
    @ObservedObject var viewModel: CyclingViewModel

    var body: some View {
        HStack {
            Spacer()
            Button(action: {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(viewModel.isRecording ? .red : .green)
                    Text(viewModel.isRecording ? "Stop Recording" : "Start Recording")
                        .foregroundColor(.primary)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemGray6))
    }
}

#Preview {
    ContentView()
}
