//
//  ResultsView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/7/24.
//


// Views/ResultsView.swift

import SwiftUI

struct ResultsView: View {
    @ObservedObject var viewModel: ModelTrainingViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Training Results")
                .font(.largeTitle)
                .padding(.bottom, 10)
            
            if let bestAccuracy = viewModel.bestAccuracy {
                Text("Best RMSE: \(String(format: "%.4f", bestAccuracy))")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            
            // Add graphs and accuracy tables
            // Placeholder for graphs
            VStack {
                Text("Predicted Cadence vs Actual Cadence")
                    .font(.headline)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(Text("Graph Placeholder"))
            }
            .padding(.bottom)
            
            VStack {
                Text("Predicted Terrain vs Actual Terrain")
                    .font(.headline)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(Text("Graph Placeholder"))
            }
            .padding(.bottom)
            
            VStack {
                Text("Predicted Position vs Actual Position")
                    .font(.headline)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(Text("Graph Placeholder"))
            }
            
            Spacer()
        }
        .padding()
    }
}
