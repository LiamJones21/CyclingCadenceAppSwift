//
//  SessionsView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/7/24.
//


// Views/SessionsView.swift

import SwiftUI

struct SessionsView: View {
    @ObservedObject var viewModel: ModelTrainingViewModel
    @State private var selectedSessions = Set<UUID>()
    @State private var showSessionSelector = false
    @State private var selectedSessionsToTrain: [Session] = []
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Sessions")
                .font(.largeTitle)
                .padding(.bottom, 10)
            
            List(selection: $selectedSessions) {
                Section(header: Text("Local Sessions")) {
                    ForEach(viewModel.sessions) { session in
                        Text(session.name ?? session.dateFormatted)
                            .tag(session.id)
                    }
                }
                
                if !viewModel.phoneSessions.isEmpty {
                    Section(header: Text("Phone Sessions")) {
                        ForEach(viewModel.phoneSessions) { session in
                            HStack {
                                Text(session.name ?? session.dateFormatted)
                                    .tag(session.id)
                                Spacer()
                                Button("Download") {
                                    downloadSession(session)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle()) // Changed from InsetGroupedListStyle() to SidebarListStyle()
            .frame(minWidth: 300, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        showSessionSelector = true
                    }) {
                        Label("Select Sessions", systemImage: "checkmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showSessionSelector) {
                SessionSelectorView(sessions: viewModel.sessions, selectedSessions: $selectedSessionsToTrain)
            }
        }
        .padding()
    }
    
    func downloadSession(_ session: Session) {
        viewModel.sessions.append(session)
        viewModel.saveLocalSessions()
    }
}
