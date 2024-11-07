//
//  ModelDetailView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/7/24.
//


// Views/ModelDetailView.swift

import SwiftUI

struct ModelDetailView: View {
    var model: ModelConfig
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(model.name)
                .font(.largeTitle)
                .padding(.bottom, 10)
            
            // Display model details
            Text("Configuration:")
                .font(.headline)
            
            Text("Window Size: \(model.config.windowSize)")
            Text("Window Step: \(model.config.windowStep)")
            Text("Preprocessing Type: \(model.config.preprocessingType)")
            Text("Filtering: \(model.config.filtering)")
            Text("Scaler: \(model.config.scaler)")
            Text("Use PCA: \(model.config.usePCA ? "Yes" : "No")")
            Text("Include Acceleration: \(model.config.includeAcceleration ? "Yes" : "No")")
            Text("Include Rotation Rate: \(model.config.includeRotationRate ? "Yes" : "No")")
            
            Spacer()
        }
        .padding()
    }
}
