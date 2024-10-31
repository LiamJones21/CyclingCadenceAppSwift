//
//  ActivityView.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 26/10/2024.
// ActivityLogView.swift

import SwiftUI

struct ActivityLogView: View {
    @ObservedObject var viewModel: CyclingViewModel
    @State private var selectedLogTypes: Set<ActivityLogEntry.LogType> = Set(ActivityLogEntry.LogType.allCases)

    var body: some View {
        VStack {
            // Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(ActivityLogEntry.LogType.allCases, id: \.self) { logType in
                        Button(action: {
                            if selectedLogTypes.contains(logType) {
                                selectedLogTypes.remove(logType)
                            } else {
                                selectedLogTypes.insert(logType)
                            }
                        }) {
                            Text(logType.rawValue)
                                .padding(8)
                                .background(selectedLogTypes.contains(logType) ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }

            List {
                // Group entries by session date
                ForEach(sortedSessionDates, id: \.self) { sessionDate in
                    Section(header: Text(formatSessionDate(sessionDate))) {
                        if let entries = groupedLogEntries[sessionDate] {
                            ForEach(entries.filter { selectedLogTypes.contains($0.logType) }) { logEntry in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(logEntry.message)
                                        Text(formatDate(logEntry.timestamp))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text(logEntry.logType.rawValue)
                                        .font(.caption)
                                        .padding(4)
                                        .background(colorForLogType(logEntry.logType))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Activity Log")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.clearActivityLog()
                }) {
                    Text("Clear")
                }
            }
        }
    }

    var groupedLogEntries: [Date: [ActivityLogEntry]] {
        Dictionary(grouping: viewModel.activityLog) { entry in
            entry.sessionDate ?? Date.distantPast
        }
    }

    var sortedSessionDates: [Date] {
        groupedLogEntries.keys.sorted(by: >)
    }

    func formatSessionDate(_ date: Date) -> String {
        if date == Date.distantPast {
            return "General"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Session \(formatter.string(from: date))"
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    func colorForLogType(_ logType: ActivityLogEntry.LogType) -> Color {
        switch logType {
        case .watchStart:
            return .blue
        case .watchStop:
            return .purple
        case .phoneStart:
            return .green
        case .phoneStop:
            return .red
        case .connected:
            return .orange
        case .disconnected:
            return .gray
        case .savedBatch:
            return .pink
        case .sessionCreated:
            return .black
        }
    }
}
