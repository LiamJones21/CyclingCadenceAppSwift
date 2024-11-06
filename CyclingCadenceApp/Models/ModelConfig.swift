//
//  ModelConfig.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 10/31/24.
//


// ModelConfig.swift

import Foundation

struct ModelConfig: Identifiable, Codable {
    var id = UUID()
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
        // Add other preprocessing parameters as needed
    }
}
