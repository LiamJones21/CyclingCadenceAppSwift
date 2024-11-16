//
//  TrainingSettings.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/11/24.
//


// TrainingSettings.swift

import Foundation

struct TrainingSettings: Equatable {
    var windowSizes: [Double]
    var windowSteps: [Double]
    var modelTypes: Set<String>
    var preprocessingTypes: Set<String>
    var filteringOptions: Set<String>
    var scalerOptions: Set<String>
    var usePCA: Bool
    var includeAcceleration: Bool
    var includeRotationRate: Bool
    var isAutomatic: Bool
    var maxTrainingTime: Double
    var selectedSessionIDs: Set<UUID>
}

extension TrainingSettings {
    init?(from dictionary: [String: Any]) {
        guard let windowSizes = dictionary["windowSizes"] as? [Double],
              let windowSteps = dictionary["windowSteps"] as? [Double],
              let modelTypes = dictionary["modelTypes"] as? [String],
              let preprocessingTypes = dictionary["preprocessingTypes"] as? [String],
              let filteringOptions = dictionary["filteringOptions"] as? [String],
              let scalerOptions = dictionary["scalerOptions"] as? [String],
              let usePCA = dictionary["usePCA"] as? Bool,
              let includeAcceleration = dictionary["includeAcceleration"] as? Bool,
              let includeRotationRate = dictionary["includeRotationRate"] as? Bool,
              let isAutomatic = dictionary["isAutomatic"] as? Bool,
              let maxTrainingTime = dictionary["maxTrainingTime"] as? Double,
              let selectedSessionIDsStrings = dictionary["selectedSessionIDs"] as? [String] else {
            return nil
        }
        // Perform compactMap outside of guard let
        let selectedSessionIDs = selectedSessionIDsStrings.compactMap { UUID(uuidString: $0) }
        
        self.windowSizes = windowSizes
        self.windowSteps = windowSteps
        self.modelTypes = Set(modelTypes)
        self.preprocessingTypes = Set(preprocessingTypes)
        self.filteringOptions = Set(filteringOptions)
        self.scalerOptions = Set(scalerOptions)
        self.usePCA = usePCA
        self.includeAcceleration = includeAcceleration
        self.includeRotationRate = includeRotationRate
        self.isAutomatic = isAutomatic
        self.maxTrainingTime = maxTrainingTime
        self.selectedSessionIDs = Set(selectedSessionIDs)
    }
}
