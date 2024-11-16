//

//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// CyclingData.swift

import Foundation
import CoreLocation

struct CyclingData: Codable {
    var timestamp: Date
    var speed: Double
    var cadence: Double
    var gear: Int
    var terrain: String
    var isStanding: Bool
    var sensorData: SensorData
    var location: LocationData?

    func toDictionary() -> [String: Any] {
        return [
            "timestamp": timestamp.iso8601,
            "speed": speed,
            "cadence": cadence,
            "gear": gear,
            "terrain": terrain,
            "isStanding": isStanding,
            "sensorData": sensorData.toDictionary(),
            "location": location?.toDictionary() ?? NSNull()
        ]
    }

    static func fromDictionary(_ dict: [String: Any]) -> CyclingData? {
        guard let timestampString = dict["timestamp"] as? String,
              let timestamp = ISO8601DateFormatter().date(from: timestampString),
              let speed = dict["speed"] as? Double,
              let cadence = dict["cadence"] as? Double,
              let gear = dict["gear"] as? Int,
              let terrain = dict["terrain"] as? String,
              let isStanding = dict["isStanding"] as? Bool,
              let sensorDataDict = dict["sensorData"] as? [String: Any],
              let sensorData = SensorData.fromDictionary(sensorDataDict) else { // Unwrap sensorData here
            return nil
        }

        let locationData = (dict["location"] as? [String: Any]).flatMap { LocationData.fromDictionary($0) }
        return CyclingData(timestamp: timestamp, speed: speed, cadence: cadence, gear: gear, terrain: terrain, isStanding: isStanding, sensorData: sensorData, location: locationData)
    }
}

struct SensorData: Codable {
    var accelerationX: Double
    var accelerationY: Double
    var accelerationZ: Double
    var rotationRateX: Double
    var rotationRateY: Double
    var rotationRateZ: Double

    func toDictionary() -> [String: Any] {
        return [
            "accelerationX": accelerationX,
            "accelerationY": accelerationY,
            "accelerationZ": accelerationZ,
            "rotationRateX": rotationRateX,
            "rotationRateY": rotationRateY,
            "rotationRateZ": rotationRateZ
        ]
    }

    static func fromDictionary(_ dict: [String: Any]) -> SensorData? {
        guard let accelerationX = dict["accelerationX"] as? Double,
              let accelerationY = dict["accelerationY"] as? Double,
              let accelerationZ = dict["accelerationZ"] as? Double,
              let rotationRateX = dict["rotationRateX"] as? Double,
              let rotationRateY = dict["rotationRateY"] as? Double,
              let rotationRateZ = dict["rotationRateZ"] as? Double else {
            return nil
        }

        return SensorData(accelerationX: accelerationX, accelerationY: accelerationY, accelerationZ: accelerationZ, rotationRateX: rotationRateX, rotationRateY: rotationRateY, rotationRateZ: rotationRateZ)
    }
}

struct LocationData: Codable {
    var latitude: Double
    var longitude: Double

    func toDictionary() -> [String: Any] {
        return [
            "latitude": latitude,
            "longitude": longitude
        ]
    }

    static func fromDictionary(_ dict: [String: Any]) -> LocationData? {
        guard let latitude = dict["latitude"] as? Double,
              let longitude = dict["longitude"] as? Double else {
            return nil
        }

        return LocationData(latitude: latitude, longitude: longitude)
    }
}
