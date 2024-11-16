//
//  SessionsView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/7/24.
//


// SessionsView.swift
import SwiftUI

struct SessionsView: View {
    @ObservedObject var viewModel: ModelTrainingViewModel
    @State private var selectedLocalSessions = Set<UUID>()
    @State private var selectedPhoneSessions = Set<UUID>()

    var body: some View {
        VStack(alignment: .leading) {
            Text("Sessions")
                .font(.largeTitle)
                .padding(.bottom, 10)

            List {
                Section(header: Text("Local Sessions")) {
                    ForEach(viewModel.sessions) { session in
                        HStack {
                            Text(session.name ?? session.dateFormatted)
                            Spacer()
                            Button(action: {
                                // Send session to phone
                                sendSessionToPhone(session)
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                if !viewModel.phoneSessions.isEmpty {
                    Section(header: Text("Phone Sessions")) {
                        ForEach(viewModel.phoneSessions) { session in
                            HStack {
                                Text(session.name ?? session.dateFormatted)
                                Spacer()
                                Button(action: {
                                    // Request session from phone
                                    requestSessionFromPhone(session)
                                }) {
                                    Image(systemName: "square.and.arrow.down")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 300, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        viewModel.requestSessionsFromPhone()
                    }) {
                        Label("Refresh Phone Sessions", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .padding()
    }

    func sendSessionToPhone(_ session: Session) {
        // Implement sending session to phone
        if let peerID = viewModel.connectedPeers.first {
            let sessionData = session.toDictionary()
            let message: [String: Any] = ["type": "sessionData", "session": sessionData]
            viewModel.sendMessage(message: message, to: peerID)
        }
    }

    func requestSessionFromPhone(_ session: Session) {
        // Implement requesting session from phone
        if let peerID = viewModel.connectedPeers.first {
            let message: [String: Any] = ["type": "requestSessionData", "sessionID": session.id.uuidString]
            viewModel.sendMessage(message: message, to: peerID)
        }
    }
}
