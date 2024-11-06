//
//  Array&Stats.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//

// Array+Statistics.swift

import Foundation

extension Array where Element == Double {
    func average() -> Double {
        guard !self.isEmpty else { return 0.0 }
        let sum = self.reduce(0, +)
        return sum / Double(self.count)
    }

    func standardDeviation() -> Double {
        guard self.count > 1 else { return 0.0 }
        let mean = self.average()
        let variance = self.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(self.count - 1)
        return sqrt(variance)
    }
}
