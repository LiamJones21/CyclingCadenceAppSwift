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
                        
                        // Tuning Value with increment buttons and manual input
                        HStack {
                            Text("Tuning Value:")
                            Spacer()
                            Button(action: {
                                viewModel.accelerometerTuningValue -= 0.1
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.blue)
                            }
                            Button(action: {
                                showTuningValueInput = true
                            }) {
                                Text(String(format: "%.1f", viewModel.accelerometerTuningValue))
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            Button(action: {
                                viewModel.accelerometerTuningValue += 0.1
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Direction Weightings
                        Text("Direction Weightings:")
                            .padding(.horizontal)
                        
                        // Weighting X with increment buttons and manual input
                        HStack {
                            Text("X:")
                            Spacer()
                            Button(action: {
                                viewModel.accelerometerWeightingX -= 0.1
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.blue)
                            }
                            Button(action: {
                                showWeightingXInput = true
                            }) {
                                Text(String(format: "%.1f", viewModel.accelerometerWeightingX))
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            Button(action: {
                                viewModel.accelerometerWeightingX += 0.1
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Weighting Y with increment buttons and manual input
                        HStack {
                            Text("Y:")
                            Spacer()
                            Button(action: {
                                viewModel.accelerometerWeightingY -= 0.1
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.blue)
                            }
                            Button(action: {
                                showWeightingYInput = true
                            }) {
                                Text(String(format: "%.1f", viewModel.accelerometerWeightingY))
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            Button(action: {
                                viewModel.accelerometerWeightingY += 0.1
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Weighting Z with increment buttons and manual input
                        HStack {
                            Text("Z:")
                            Spacer()
                            Button(action: {
                                viewModel.accelerometerWeightingZ -= 0.1
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.blue)
                            }
                            Button(action: {
                                showWeightingZInput = true
                            }) {
                                Text(String(format: "%.1f", viewModel.accelerometerWeightingZ))
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            Button(action: {
                                viewModel.accelerometerWeightingZ += 0.1
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Low-Pass Filter Toggle
                        Toggle("Use Low-Pass Filter", isOn: $viewModel.useLowPassFilter)
                            .toggleStyle(SwitchToggleStyle())
                            .padding(.horizontal)
                        
                        if viewModel.useLowPassFilter {
                            // Low-Pass Filter Alpha with increment buttons and manual input
                            HStack {
                                Text("Filter Alpha:")
                                Spacer()
                                Button(action: {
                                    viewModel.lowPassFilterAlpha -= 0.01
                                }) {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.blue)
                                }
                                Button(action: {
                                    showFilterAlphaInput = true
                                }) {
                                    Text(String(format: "%.2f", viewModel.lowPassFilterAlpha))
                                        .foregroundColor(.blue)
                                        .underline()
                                }
                                Button(action: {
                                    viewModel.lowPassFilterAlpha += 0.01
                                }) {
                                    Image(systemName: "plus.circle")
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
                        
                        // Process Noise Q with increment buttons and manual input
                        HStack {
                            Text("Process Noise Q:")
                            Spacer()
                            Button(action: {
                                viewModel.kalmanProcessNoise -= 0.1
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.blue)
                            }
                            Button(action: {
                                showProcessNoiseInput = true
                            }) {
                                Text(String(format: "%.1f", viewModel.kalmanProcessNoise))
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            Button(action: {
                                viewModel.kalmanProcessNoise += 0.1
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Measurement Noise R with increment buttons and manual input
                        HStack {
                            Text("Measurement Noise R:")
                            Spacer()
                            Button(action: {
                                viewModel.kalmanMeasurementNoise -= 0.1
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.blue)
                            }
                            Button(action: {
                                showMeasurementNoiseInput = true
                            }) {
                                Text(String(format: "%.1f", viewModel.kalmanMeasurementNoise))
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            Button(action: {
                                viewModel.kalmanMeasurementNoise += 0.1
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // GPS Accuracy Threshold with increment buttons and manual input
                        HStack {
                            Text("GPS Accuracy Threshold:")
                            Spacer()
                            Button(action: {
                                viewModel.gpsAccuracyThreshold -= 1.0
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.blue)
                            }
                            Button(action: {
                                showGPSAccuracyThresholdInput = true
                            }) {
                                Text(String(format: "%.0f m", viewModel.gpsAccuracyThreshold))
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            Button(action: {
                                viewModel.gpsAccuracyThreshold += 1.0
                            }) {
                                Image(systemName: "plus.circle")
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
