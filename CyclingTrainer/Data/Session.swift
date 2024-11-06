//
//  Session.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


import Foundation

struct Session: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var name: String?
    var data: [CyclingData]
}