//
//  UTType+Extensions.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/7/24.
//

// UTType+Extensions.swift

import UniformTypeIdentifiers

extension UTType {
    /// A custom UTType for Core ML model files with the `.mlmodel` extension.
    static var coreMLModel: UTType {
        UTType(importedAs: "com.apple.coreml.mlmodel")
    }
}
