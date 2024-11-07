//
//  ContentView.swift
//  CyclingTrainer
//
//  Created by Jones, Liam on 11/6/24.
// Views/ContentView.swift

// Views/ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = ModelTrainingViewModel()
    @State private var showTrainingSettings = false
    @State private var selectedView: SidebarItem = .home
    
    var body: some View {
        NavigationView {
            SidebarView(viewModel: viewModel, selectedView: $selectedView)
            
            switch selectedView {
            case .home:
                HomePageView()
            case .info:
                InfoView()
            case .sessions:
                SessionsView(viewModel: viewModel)
            case .models:
                ModelsView(viewModel: viewModel)
            case .training:
                TrainingAndLogsView(viewModel: viewModel)
            case .results:
                ResultsView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
        .onReceive(NotificationCenter.default.publisher(for: .openTrainingSettings)) { _ in
            self.selectedView = .training
        }
    }
}

enum SidebarItem {
    case home
    case info
    case sessions
    case models
    case training
    case results
}
