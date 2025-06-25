//
//  Downsample.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 6/24/25.
//

import Accelerate

public func downsampleComplex(iqData: [DSPComplex], decimationFactor: Int, filter: [Float] = [0.5, 0.5]) -> [DSPComplex] {
    let iqDataCopy = iqData
    var returnVector: [DSPComplex] = .init(repeating: DSPComplex(real: 0, imag: 0), count: iqDataCopy.count / decimationFactor)
    var splitComplexData = DSPSplitComplex(realp: .allocate(capacity: iqDataCopy.count), imagp: .allocate(capacity: iqDataCopy.count))
    defer {
        splitComplexData.realp.deallocate()
        splitComplexData.imagp.deallocate()
    }
    vDSP.convert(interleavedComplexVector: iqDataCopy, toSplitComplexVector: &splitComplexData)
    let iBranchBufferPointer = UnsafeBufferPointer(start: splitComplexData.realp, count: iqDataCopy.count)
    let qBranchBufferPointer = UnsafeBufferPointer(start: splitComplexData.imagp, count: iqDataCopy.count)
    var iBranchDownsampled = vDSP.downsample(iBranchBufferPointer, decimationFactor: decimationFactor, filter: filter)
    var qBranchDownsampled = vDSP.downsample(qBranchBufferPointer, decimationFactor: decimationFactor, filter: filter)
    return iBranchDownsampled.withUnsafeMutableBufferPointer { iDownsampledBufferPointer in
        qBranchDownsampled.withUnsafeMutableBufferPointer { qDownsampledBufferPointer in
            let splitDownsampledData = DSPSplitComplex(realp: iDownsampledBufferPointer.baseAddress!, imagp: qDownsampledBufferPointer.baseAddress!)
            vDSP.convert(splitComplexVector: splitDownsampledData, toInterleavedComplexVector: &returnVector)
            return returnVector
        }
    }
}

public func downsampleReal(data: [Float], decimationFactor: Int, filter: [Float] = [0.5, 0.5]) -> [Float] {
    return vDSP.downsample(data, decimationFactor: decimationFactor, filter: filter)
}
