//
//  ModelConfig.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


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