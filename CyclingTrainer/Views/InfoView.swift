//
//  InfoView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/7/24.
//


// Views/InfoView.swift

import SwiftUI

struct InfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("About Cycling Trainer")
                .font(.largeTitle)
                .bold()
            
            Text("This application allows you to train machine learning models for cycling cadence prediction.")
            
            // Add more information as needed
            
            Spacer()
        }
        .padding()
    }
}