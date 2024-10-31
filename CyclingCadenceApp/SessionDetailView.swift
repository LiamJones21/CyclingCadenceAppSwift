//
//  SessionDetailView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// SessionDetailView.swift

import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @State private var showGraphView = false

    var body: some View {
        VStack {
            Button(action: {
                showGraphView = true
            }) {
                Text("Show Graphs")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
            }
            .sheet(isPresented: $showGraphView) {
                GraphView(session: session)
            }

            List {
                // Table Header
                HStack {
                    Text("Time").bold().frame(width: 80, alignment: .leading)
                    Spacer()
                    Text("Speed").bold().frame(width: 60, alignment: .leading)
                    Spacer()
                    Text("Cadence").bold().frame(width: 70, alignment: .leading)
                    Spacer()
                    Text("Terrain").bold().frame(width: 70, alignment: .leading)
                    Spacer()
                    Text("Position").bold().frame(width: 70, alignment: .leading)
                }

                ForEach(session.data, id: \.timestamp) { data in
                    HStack {
                        Text("\(formattedTime(from: data.timestamp))")
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                        Text(String(format: "%.2f", data.speed))
                            .frame(width: 60, alignment: .leading)
                        Spacer()
                        Text(String(format: "%.0f", data.cadence))
                            .frame(width: 70, alignment: .leading)
                        Spacer()
                        Text("\(data.terrain)")
                            .frame(width: 70, alignment: .leading)
                        Spacer()
                        if let location = data.location {
                            Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                                .frame(width: 70, alignment: .leading)
                        } else {
                            Text("N/A")
                                .frame(width: 70, alignment: .leading)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.dateFormatted)
    }

    func formattedTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SS"
        return formatter.string(from: date)
    }
}

