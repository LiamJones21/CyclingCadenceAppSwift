//
//  SidebarView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/7/24.
//


// SidebarView.swift

import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: ModelTrainingViewModel
    @Binding var selectedView: SidebarItem?

    var body: some View {
        List(selection: $selectedView) {
            Section(header: Text("Navigation")) {
                NavigationLink(destination: HomePageView(), tag: SidebarItem.home, selection: $selectedView) {
                    Label("Home", systemImage: "house")
                }
                NavigationLink(destination: InfoView(), tag: SidebarItem.info, selection: $selectedView) {
                    Label("Info", systemImage: "info.circle")
                }
                NavigationLink(destination: SessionsView(viewModel: viewModel), tag: SidebarItem.sessions, selection: $selectedView) {
                    Label("Sessions", systemImage: "doc.text")
                }
                NavigationLink(destination: ModelsView(viewModel: viewModel), tag: SidebarItem.models, selection: $selectedView) {
                    Label("Models", systemImage: "cube.box")
                }
                NavigationLink(destination: TrainingAndLogsView(viewModel: viewModel), tag: SidebarItem.training, selection: $selectedView) {
                    Label("Training", systemImage: "play.circle")
                }
                NavigationLink(destination: ResultsView(viewModel: viewModel), tag: SidebarItem.results, selection: $selectedView) {
                    Label("Results", systemImage: "chart.bar")
                }
            }
            
            Section(header: Text("Actions")) {
                Button(action: {
                    viewModel.requestSessionsFromPhone()
                }) {
                    Label("Download Sessions from Phone", systemImage: "arrow.down.circle")
                }
                Button(action: {
                    viewModel.requestModelsFromPhone()
                }) {
                    Label("Download Models from Phone", systemImage: "arrow.down.square")
                }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
}
