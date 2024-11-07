//
//  HomePageView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


// Views/HomePageView.swift

import SwiftUI

struct HomePageView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Welcome to Cycling Trainer")
                .font(.largeTitle)
                .bold()

            Text("Step-by-Step Instructions")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 10) {
                Text("1. Connect your iPhone to the Mac via the Cycling Cadence App.")
                Text("2. Select the sessions you want to use for training from the sidebar.")
                Text("3. Choose between Manual or Automatic training modes.")
                Text("4. Configure the training parameters as needed.")
                Text("5. Click 'Start Training' to begin the model training process.")
                Text("6. Monitor the training logs and best RMSE value in real-time.")
                Text("7. After training, send the trained model to your iPhone for deployment.")
            }
            .padding()

            Spacer()
        }
        .padding()
    }
}
