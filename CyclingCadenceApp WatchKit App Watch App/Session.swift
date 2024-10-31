//
//  Session.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// Session.swift

import Foundation

struct Session: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var data: [CyclingData]
}
