//
//  SensorData.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// CyclingData.swift

import Foundation
import CoreLocation



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

// Prediction Result Model
struct PredictionResult: Codable, Identifiable {
    var id = UUID()
    var timestamp: Date
    var cadence: Double
    var gear: Int
    var terrain: String
    var isStanding: Bool
    var speed: Double
}
