//
//  TrainingAndLogsView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


// Views/TrainingAndLogsView.swift

import SwiftUI

struct TrainingAndLogsView: View {
    @ObservedObject var viewModel: ModelTrainingViewModel

    var body: some View {
        VStack(alignment: .leading) {
            ModelTrainingView(viewModel: viewModel)

            if let bestAcc = viewModel.bestAccuracy {
                HStack {
                    Text("Best RMSE: \(String(format: "%.2f", bestAcc))")
                        .font(.title2)
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding([.leading, .trailing, .bottom], 10)
            }

            if !viewModel.trainingLogs.isEmpty {
                VStack(alignment: .leading) {
                    Text("Training Logs")
                        .font(.headline)
                    ScrollView {
                        Text(viewModel.trainingLogs)
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .background(Color(white: 0.95))
                    .cornerRadius(8)
                }
                .padding([.leading, .trailing], 10)
            }

            Spacer()
        }
    }
}
