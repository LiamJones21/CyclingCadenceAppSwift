//
//  SettingsView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/4/24.
/// SettingsView.swift

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
    @State private var showGPSAccuracyLowerBoundInput = false
    @State private var showGPSAccuracyUpperBoundInput = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.title)
                    .padding(.horizontal)
                
                Toggle("Use Accelerometer", isOn: $viewModel.useAccelerometer)
                    .toggleStyle(SwitchToggleStyle())
                    .padding(.horizontal)
                
                if viewModel.useAccelerometer {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Accelerometer Settings")
                            .font(.headline)
                            .padding(.horizontal)
                        
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
                        
                        Text("Direction Weightings:")
                            .padding(.horizontal)
                        
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
                        
                        Toggle("Use Low-Pass Filter", isOn: $viewModel.useLowPassFilter)
                            .toggleStyle(SwitchToggleStyle())
                            .padding(.horizontal)
                        
                        if viewModel.useLowPassFilter {
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
                
                Toggle("Use GPS", isOn: $viewModel.useGPS)
                    .toggleStyle(SwitchToggleStyle())
                    .padding(.horizontal)
                
                if viewModel.useGPS {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("GPS Settings")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack {
                            Text("GPS Accuracy Lower Bound:")
                            Spacer()
                            Button(action: {
                                viewModel.gpsAccuracyLowerBound -= 1.0
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.blue)
                            }
                            Button(action: {
                                showGPSAccuracyLowerBoundInput = true
                            }) {
                                Text(String(format: "%.0f m", viewModel.gpsAccuracyLowerBound))
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            Button(action: {
                                viewModel.gpsAccuracyLowerBound += 1.0
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            Text("GPS Accuracy Upper Bound:")
                            Spacer()
                            Button(action: {
                                viewModel.gpsAccuracyUpperBound -= 1.0
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.blue)
                            }
                            Button(action: {
                                showGPSAccuracyUpperBoundInput = true
                            }) {
                                Text(String(format: "%.0f m", viewModel.gpsAccuracyUpperBound))
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            Button(action: {
                                viewModel.gpsAccuracyUpperBound += 1.0
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                if viewModel.useAccelerometer && viewModel.useGPS {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Kalman Filter Settings")
                            .font(.headline)
                            .padding(.horizontal)
                        
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
                    }
                    .padding(.top, 10)
                }
                
                Spacer()
                
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding()
                }
            }
            .padding()
        }
    }
    
    struct SettingsView_Previews: PreviewProvider {
        static var previews: some View {
            SettingsView().environmentObject(WatchViewModel())
        }
    }
    
}
