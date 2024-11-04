//
//  SettingsView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/4/24.
// SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: WatchViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showTuningValueInput = false
    @State private var showWeightingXInput = false
    @State private var showWeightingYInput = false
    @State private var showWeightingZInput = false
    @State private var showFilterAlphaInput = false
    @State private var showProcessNoiseInput = false
    @State private var showMeasurementNoiseInput = false
    @State private var showGPSAccuracyThresholdInput = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // add a settings title
                Text("Settings")
                    .font(.title)
                    .padding(.horizontal)
                // Acceleration Toggle
                Toggle("Use Accelerometer", isOn: $viewModel.useAccelerometer)
                    .toggleStyle(SwitchToggleStyle())
                    .padding(.horizontal)
                
                if viewModel.useAccelerometer {
                    // Accelerometer Settings
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Accelerometer Settings")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Tuning Value
                        HStack {
                            Text("Tuning Value:")
                            Spacer()
                            Button(action: {
                                showTuningValueInput = true
                            }) {
                                Text(String(format: "%.1f", viewModel.accelerometerTuningValue))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Direction Weightings
                        Text("Direction Weightings:")
                            .padding(.horizontal)
                        
                        HStack {
                            Text("X:")
                            Spacer()
                            Button(action: {
                                showWeightingXInput = true
                            }) {
                                Text(String(format: "%.1f", viewModel.accelerometerWeightingX))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            Text("Y:")
                            Spacer()
                            Button(action: {
                                showWeightingYInput = true
                            }) {
                                Text(String(format: "%.1f", viewModel.accelerometerWeightingY))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            Text("Z:")
                            Spacer()
                            Button(action: {
                                showWeightingZInput = true
                            }) {
                                Text(String(format: "%.1f", viewModel.accelerometerWeightingZ))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Low-Pass Filter Toggle
                        Toggle("Use Low-Pass Filter", isOn: $viewModel.useLowPassFilter)
                            .toggleStyle(SwitchToggleStyle())
                            .padding(.horizontal)
                        
                        if viewModel.useLowPassFilter {
                            // Low-Pass Filter Alpha
                            HStack {
                                Text("Filter Alpha:")
                                Spacer()
                                Button(action: {
                                    showFilterAlphaInput = true
                                }) {
                                    Text(String(format: "%.2f", viewModel.lowPassFilterAlpha))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 10)
                }
                
                // GPS Toggle
                Toggle("Use GPS", isOn: $viewModel.useGPS)
                    .toggleStyle(SwitchToggleStyle())
                    .padding(.horizontal)
                
                if viewModel.useGPS {
                    // GPS Settings (if any can be added here in future)
                    Text("GPS is enabled for speed calculation.")
                        .font(.subheadline)
                        .padding(.horizontal)
                }
                
                // Kalman Filter Settings
                if viewModel.useAccelerometer && viewModel.useGPS {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Kalman Filter Settings")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Process Noise Q
                        HStack {
                            Text("Process Noise Q:")
                            Spacer()
                            Button(action: {
                                showProcessNoiseInput = true
                            }) {
                                Text(String(format: "%.1f", viewModel.kalmanProcessNoise))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Measurement Noise R
                        HStack {
                            Text("Measurement Noise R:")
                            Spacer()
                            Button(action: {
                                showMeasurementNoiseInput = true
                            }) {
                                Text(String(format: "%.1f", viewModel.kalmanMeasurementNoise))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // GPS Accuracy Threshold
                        HStack {
                            Text("GPS Accuracy Threshold:")
                            Spacer()
                            Button(action: {
                                showGPSAccuracyThresholdInput = true
                            }) {
                                Text(String(format: "%.0f m", viewModel.gpsAccuracyThreshold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 10)
                }
                
                Spacer()
                
                // Done Button
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding()
                }
            }
            // Removed .navigationBarTitle and .navigationBarItems
            .padding()
        }
        // Remove navigationBarTitle and navigationBarItems
        // Alternatively, if you want a title, you can add a Text at the top
        // Example:
//        .overlay(
//            Text("Settings")
//                .font(.headline)
//                .padding(),
//            alignment: .top
//        )
        // Ensure the "Done" button is accessible
    }
    
    struct SettingsView_Previews: PreviewProvider {
        static var previews: some View {
            SettingsView().environmentObject(WatchViewModel())
        }
    }
}
