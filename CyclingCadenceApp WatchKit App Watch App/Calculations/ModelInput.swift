//
//  ModelInput.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/3/24.
//


// ModelInput.swift
// CyclingCadenceApp

import Foundation
import CoreML

class ModelInput: MLFeatureProvider {
    var features: MLMultiArray

    var featureNames: Set<String> {
        return ["input"]
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "input" {
            return MLFeatureValue(multiArray: features)
        }
        return nil
    }

    init(features: MLMultiArray) {
        self.features = features
    }
}
