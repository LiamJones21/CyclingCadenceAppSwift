//
//  Session.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// Session.swift

import Foundation

import Foundation

struct Session: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var data: [CyclingData]
    var name: String? // Added name property

    var displayName: String {
        name ?? dateFormatted
    }
}

