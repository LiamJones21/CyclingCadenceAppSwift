//

//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// CyclingData.swift

import Foundation
import CoreLocation

struct SensorData: Codable {
    var x: Double
    var y: Double
    var z: Double
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
    var accelerometerData: SensorData
    var location: LocationData?
}
