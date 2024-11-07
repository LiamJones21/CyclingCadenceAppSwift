//
//  ContentView.swift
//  CyclingTrainer
//
//  Created by Jones, Liam on 11/6/24.
// Views/ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = ModelTrainingViewModel()

    var body: some View {
        NavigationView {
            // Sidebar: Sessions
            SidebarView(viewModel: viewModel)
            
            // Main Content: Training Configuration and Logs
            TrainingAndLogsView(viewModel: viewModel)
            
            // Sidebar: Models
            ModelManagerView(viewModel: viewModel)
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
}

struct SidebarView: View {
    @ObservedObject var viewModel: ModelTrainingViewModel

    var body: some View {
        VStack(alignment: .leading) {
            Text("Sessions")
                .font(.title2)
                .padding(.top, 10)
                .padding(.bottom, 5)

            List(selection: $viewModel.selectedSessions) {
                ForEach(viewModel.sessions) { session in
                    Text(session.name ?? session.dateFormatted)
                }
            }
            .frame(maxHeight: .infinity)
            .listStyle(SidebarListStyle())

            Spacer()

            Button(action: {
                requestSessionsFromPhone()
            }) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                    Text("Download Sessions")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding([.leading, .trailing, .bottom], 10)
        }
        .frame(width: 250)
        .background(Color(white: 0.95))
    }

    private func requestSessionsFromPhone() {
        guard let peerID = viewModel.connectedPeers.first else {
            print("No connected peers to request sessions from.")
            return
        }
        let message: [String: Any] = ["type": "requestSessionsList"]
        viewModel.sendMessage(message: message, to: peerID)
    }
}

