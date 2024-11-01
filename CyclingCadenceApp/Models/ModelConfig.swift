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
        var includeFFT: Bool
        var includeWavelet: Bool
        // Add other preprocessing parameters as needed
    }
}
