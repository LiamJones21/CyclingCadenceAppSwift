//
//  DataCollector.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/3/24.
// DataCollector.swift
// CyclingCadenceApp

import Foundation
import CoreMotion
import CoreLocation

class DataCollector {
    private var collectedData: [CyclingData] = []
    private var unsentData: [CyclingData] = []

    var gearRatios: [String] = []
    var wheelCircumference: Double = 2.1 // Default value in meters

    var dataCount: Int {
        return collectedData.count
    }

    // Reference to SpeedCalculator to access offsets
    private let speedCalculator: SpeedCalculator

    init(speedCalculator: SpeedCalculator) {
        self.speedCalculator = speedCalculator
    }

    func resetData() {
        collectedData.removeAll()
        unsentData.removeAll()
    }

    // DataCollector.swift

    func collectData(
        deviceMotionData: CMDeviceMotion,
        speed: Double,
        gear: Int,
        terrain: String,
        isStanding: Bool,
        location: CLLocation?
    ) {
        // Adjust for offsets
        let accelerationX = deviceMotionData.userAcceleration.x - speedCalculator.accelOffsetX
        let accelerationY = deviceMotionData.userAcceleration.y - speedCalculator.accelOffsetY
        let accelerationZ = deviceMotionData.userAcceleration.z - speedCalculator.accelOffsetZ

        let rotationRateX = deviceMotionData.rotationRate.x - speedCalculator.rotationOffsetX
        let rotationRateY = deviceMotionData.rotationRate.y - speedCalculator.rotationOffsetY
        let rotationRateZ = deviceMotionData.rotationRate.z - speedCalculator.rotationOffsetZ

        // Collect data
        let sensorData = SensorData(
            accelerationX: accelerationX,
            accelerationY: accelerationY,
            accelerationZ: accelerationZ,
            rotationRateX: rotationRateX,
            rotationRateY: rotationRateY,
            rotationRateZ: rotationRateZ
        )

        let locationData: LocationData? = location != nil ? LocationData(
            latitude: location!.coordinate.latitude,
            longitude: location!.coordinate.longitude
        ) : nil

        let cadence = estimateCadence(speed: speed, gear: gear)

        let cyclingData = CyclingData(
            timestamp: Date(),
            speed: speed,
            cadence: cadence,
            gear: gear,
            terrain: terrain,
            isStanding: isStanding,
            sensorData: sensorData,
            location: locationData
        )

        collectedData.append(cyclingData)
        unsentData.append(cyclingData)
    }


    func getUnsentData() -> [CyclingData] {
        return unsentData
    }

    func clearUnsentData() {
        unsentData.removeAll()
    }
    // Cadence estimation function
    func estimateCadence(speed: Double, gear: Int) -> Double {
        guard gear > 0,
              gear <= gearRatios.count,
              let gearRatio = Double(gearRatios[gear - 1]),
              wheelCircumference > 0 else {
            return 0.0
        }

        // Calculate cadence (RPM)
        let cadence = (speed / wheelCircumference) * gearRatio * 60
        return cadence
    }

    // Parameter-less cadence estimation for ContentView
    func estimateCadence() -> Double? {
        guard let latestData = collectedData.last else { return nil }
        let speed = latestData.speed
        let gear = latestData.gear

        guard gear > 0,
              gear <= gearRatios.count,
              let gearRatio = Double(gearRatios[gear - 1]),
              wheelCircumference > 0 else {
            return nil
        }

        let cadence = (speed / wheelCircumference) * gearRatio * 60
        return cadence
    }

}
