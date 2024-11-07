//
//  SidebarView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/7/24.
//


// Views/SidebarView.swift

import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: ModelTrainingViewModel
    @Binding var selectedView: SidebarItem
    
    var body: some View {
        List {
            Section(header: Text("Navigation")) {
                Button(action: { selectedView = .home }) {
                    Label("Home", systemImage: "house")
                }
                Button(action: { selectedView = .info }) {
                    Label("Info", systemImage: "info.circle")
                }
                Button(action: { selectedView = .sessions }) {
                    Label("Sessions", systemImage: "doc.text")
                }
                Button(action: { selectedView = .models }) {
                    Label("Models", systemImage: "cube.box")
                }
                Button(action: { selectedView = .training }) {
                    Label("Training", systemImage: "play.circle")
                }
                Button(action: { selectedView = .results }) {
                    Label("Results", systemImage: "chart.bar")
                }
            }
            .collapsible(false)
            
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