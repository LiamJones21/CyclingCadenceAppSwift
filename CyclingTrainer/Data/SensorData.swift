//
//  SensorData.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


import Foundation

struct SensorData: Codable {
    var accelerationX: Double
    var accelerationY: Double
    var accelerationZ: Double
    var rotationRateX: Double
    var rotationRateY: Double
    var rotationRateZ: Double
}

struct LocationData: Codable {
    var latitude: Double
    var longitude: Double
}

struct CyclingData: Codable {
    var timestamp: Date
    var speed: Double
    var cadence: Double
    var gear: Int
    var terrain: String
    var isStanding: Bool
    var sensorData: SensorData
    var location: LocationData?
}