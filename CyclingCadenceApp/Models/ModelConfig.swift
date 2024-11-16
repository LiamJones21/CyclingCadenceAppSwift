//
//  ModelConfig.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 10/31/24.
//


// ModelConfig.swift

import Foundation

struct ModelConfig: Codable, Identifiable {
    var id: UUID
    var name: String
    var config: Config

    struct Config: Codable {
        var windowSize: Int
        var windowStep: Int
        var preprocessingType: String
        var filtering: String
        var scaler: String
        var usePCA: Bool
        var includeAcceleration: Bool
        var includeRotationRate: Bool
    }

    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "config": [
                "windowSize": config.windowSize,
                "windowStep": config.windowStep,
                "preprocessingType": config.preprocessingType,
                "filtering": config.filtering,
                "scaler": config.scaler,
                "usePCA": config.usePCA,
                "includeAcceleration": config.includeAcceleration,
                "includeRotationRate": config.includeRotationRate
            ]
        ]
    }
}
