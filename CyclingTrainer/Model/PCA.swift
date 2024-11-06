//
//  PCA.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


// PCA.swift

import Foundation
import Accelerate

class PCA {
    private var components: [[Double]] = []
    private var meanVector: [Double] = []

    init?(data: [[Double]], numComponents: Int? = nil) {
        guard !data.isEmpty else { return nil }
        let numComponents = numComponents ?? data[0].count
        computePCA(data: data, numComponents: numComponents)
    }

    private func computePCA(data: [[Double]], numComponents: Int) {
        let n = data.count
        let m = data[0].count

        // Compute mean vector
        meanVector = [Double](repeating: 0.0, count: m)
        for vector in data {
            for i in 0..<m {
                meanVector[i] += vector[i]
            }
        }
        meanVector = meanVector.map { $0 / Double(n) }

        // Subtract mean
        var meanSubtractedData = data.map { zip($0, meanVector).map(-) }

        // Flatten data into a single array
        let flattenedData = meanSubtractedData.flatMap { $0 }

        // Create matrix from data
        var dataMatrix = la_matrix_from_double_buffer(flattenedData, la_count_t(n), la_count_t(m), la_count_t(m), LA_NO_HINT, LA_ATTRIBUTE_ENABLE_LOGGING)

        // Compute covariance matrix
        let transposedDataMatrix = la_transpose(dataMatrix)
        let covarianceMatrix = la_syrk(.upper, .transposed, 1.0 / Double(n - 1), dataMatrix, 0.0, la_identity_matrix(m))

        // Convert covariance matrix to array
        var covarianceArray = [Double](repeating: 0.0, count: m * m)
        la_matrix_to_double_buffer(&covarianceArray, la_count_t(m), covarianceMatrix)

        // Perform eigen decomposition
        var eigenvalues = [Double](repeating: 0.0, count: m)
        var eigenvectors = [Double](repeating: 0.0, count: m * m)
        var workspace = [Double](repeating: 0.0, count: 15 * m)
        var info = Int32(0)
        var lwork = Int32(workspace.count)

        // Symmetric matrix eigen decomposition
        covarianceArray.withUnsafeMutableBufferPointer { covarianceBuffer in
            eigenvalues.withUnsafeMutableBufferPointer { eigenvaluesBuffer in
                eigenvectors.withUnsafeMutableBufferPointer { eigenvectorsBuffer in
                    dsyev_("V", "U", &Int32(m), covarianceBuffer.baseAddress!, &Int32(m), eigenvaluesBuffer.baseAddress!, &workspace, &lwork, &info)
                }
            }
        }

        // Sort eigenvalues and eigenvectors
        let sortedIndices = eigenvalues.enumerated().sorted(by: { $0.element > $1.element }).map { $0.offset }
        components = []
        for i in 0..<numComponents {
            let index = sortedIndices[i]
            let start = index * m
            let end = start + m
            let component = Array(eigenvectors[start..<end])
            components.append(component)
        }
    }

    func transform(data: [[Double]]) -> [[Double]] {
        var transformedData: [[Double]] = []
        for vector in data {
            let meanSubtracted = zip(vector, meanVector).map(-)
            var transformedVector: [Double] = []
            for component in components {
                let projection = dotProduct(meanSubtracted, component)
                transformedVector.append(projection)
            }
            transformedData.append(transformedVector)
        }
        return transformedData
    }

    func transform(vector: [Double]) -> [Double] {
        let meanSubtracted = zip(vector, meanVector).map(-)
        var transformedVector: [Double] = []
        for component in components {
            let projection = dotProduct(meanSubtracted, component)
            transformedVector.append(projection)
        }
        return transformedVector
    }

    private func dotProduct(_ a: [Double], _ b: [Double]) -> Double {
        var result = 0.0
        vDSP_dotprD(a, 1, b, 1, &result, vDSP_Length(a.count))
        return result
    }
}
