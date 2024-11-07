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
        let meanSubtractedData = data.map { zip($0, meanVector).map(-) }

        // Flatten data into a single array (column-major order)
        var dataFlat = meanSubtractedData.flatMap { $0 }
        let lda = __CLPK_integer(n)
        var info: __CLPK_integer = 0

        // Compute covariance matrix using DSYRK
        var covMatrix = [Double](repeating: 0.0, count: m * m)
        var uplo: Int8 = 85 // 'U' in ASCII
        var trans: Int8 = 78 // 'N' in ASCII
        var n_cblas = __CLPK_integer(m)
        var k = __CLPK_integer(n)
        var alpha = 1.0 / Double(n - 1)
        var beta = 0.0

        dataFlat.withUnsafeMutableBufferPointer { dataPtr in
            covMatrix.withUnsafeMutableBufferPointer { covPtr in
                dsyrk_(&uplo, &trans, &n_cblas, &k, &alpha, dataPtr.baseAddress!, &k, &beta, covPtr.baseAddress!, &n_cblas)
            }
        }

        // Compute eigenvalues and eigenvectors using the newer LAPACK functions
        var jobz: Int8 = 86 // 'V' in ASCII
        var range: Int8 = 65 // 'A' in ASCII
        var diag: Int8 = 85 // 'U' in ASCII
        var vl = 0.0
        var vu = 0.0
        var il: __CLPK_integer = 0
        var iu: __CLPK_integer = 0
        var abstol = -1.0
        var w = [Double](repeating: 0.0, count: m)
        var z = [Double](repeating: 0.0, count: m * m)
        var ldz = n_cblas
        var isuppz = [__CLPK_integer](repeating: 0, count: 2 * m)
        var workSize = __CLPK_integer(-1)
        var lwork: __CLPK_integer = 0
        var iworkSize = __CLPK_integer(-1)
        var liwork: __CLPK_integer = 0
        var workQuery = [Double](repeating: 0.0, count: 1)
        var iworkQuery = [__CLPK_integer](repeating: 0, count: 1)

        // Query optimal workspace size
        dsyevr_(&jobz, &range, &uplo, &n_cblas, &covMatrix, &n_cblas, &vl, &vu, &il, &iu, &abstol, &k, &w, &z, &ldz, &isuppz, &workQuery, &workSize, &iworkQuery, &iworkSize, &info)

        lwork = __CLPK_integer(workQuery[0])
        liwork = iworkQuery[0]

        var work = [Double](repeating: 0.0, count: Int(lwork))
        var iwork = [__CLPK_integer](repeating: 0, count: Int(liwork))

        // Compute eigenvalues and eigenvectors
        dsyevr_(&jobz, &range, &uplo, &n_cblas, &covMatrix, &n_cblas, &vl, &vu, &il, &iu, &abstol, &k, &w, &z, &ldz, &isuppz, &work, &lwork, &iwork, &liwork, &info)

        if info != 0 {
            print("Error in eigen decomposition: \(info)")
            return
        }

        // Sort eigenvalues and eigenvectors in descending order
        let eigenvalues = w
        let eigenvectors = z

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

    private func dotProduct(_ a: [Double], _ b: [Double]) -> Double {
        var result = 0.0
        vDSP_dotprD(a, 1, b, 1, &result, vDSP_Length(a.count))
        return result
    }
}
