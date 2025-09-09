//
//  Downsample.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 6/24/25.
//

import Accelerate


public class Downsampler {
    private var decimationFactor: Int
    private var filter: [Float]
    
    // State
    private var realContext: [Float]
    private var complexContext: [DSPComplex]
    private var currOffset: Int = 0
    
    public init?(inputSampleRate: Int, outputSampleRate: Int, filter: [Float]) {
        guard inputSampleRate > outputSampleRate, inputSampleRate % outputSampleRate == 0 else {
            print("inputSampleRate must be an integer multiple of outputSampleRate.")
            return nil
        }
        self.decimationFactor = inputSampleRate / outputSampleRate
        self.filter = filter
        realContext = []
        complexContext = []
    }
    
    public init?(inputSampleRate: Int, outputSampleRate: Int) {
        guard inputSampleRate > outputSampleRate, inputSampleRate % outputSampleRate == 0 else {
            print("inputSampleRate must be an integer multiple of outputSampleRate.")
            return nil
        }
        self.decimationFactor = inputSampleRate / outputSampleRate
        do {
            self.filter = try FIRFilter(type: .lowPass, cutoffFrequency: Double(outputSampleRate) / 2.0, sampleRate: inputSampleRate, tapsLength: 15).getTaps()
        }
        catch {
            return nil
        }
        realContext = []
        complexContext = []
    }
    
    public func downsampleReal(_ input: [Float]) -> [Float]? {
        guard input.count >= (decimationFactor) else {
            print("Downsample input not long enough.")
            return nil
        }
        var adjustedInput = consumeRealContext()
        adjustedInput.append(contentsOf: input)
        adjustedInput = Array(adjustedInput.dropFirst(currOffset))
        let usableSampleCount = adjustedInput.count - (filter.count - 1)
        let outputLength = Int(floor(Double(usableSampleCount) / Double(decimationFactor)))
        var output = [Float](repeating: 0, count: outputLength)
        
        self.currOffset = ((usableSampleCount + 1) * decimationFactor) - adjustedInput.count
        let contextStartingPoint = adjustedInput.count - 1 - (filter.count - 1)
        self.realContext = Array(adjustedInput[contextStartingPoint..<adjustedInput.count])
        
        vDSP_desamp(&adjustedInput, vDSP_Stride(decimationFactor), &self.filter, &output, vDSP_Length(outputLength), vDSP_Length(filter.count))
        return output
    }
    
    private func consumeRealContext() -> [Float] {
        var returnVal = self.realContext
        self.realContext = []
        return returnVal
    }
    
    public func downsampleComplex(_ input: [DSPComplex]) -> [DSPComplex]? {
        guard input.count >= decimationFactor else {
            print("Downsample input not long enough.")
            return nil
        }
        var adjustedInput = consumeComplexContext()
        adjustedInput.append(contentsOf: input)
        adjustedInput = Array(adjustedInput.dropFirst(currOffset))
        let usableSampleCount = adjustedInput.count - (filter.count - 1)
        let outputLength = Int(floor(Double(usableSampleCount) / Double(decimationFactor)))
        
        self.currOffset = ((usableSampleCount + 1) * decimationFactor) - adjustedInput.count
        let contextStartingPoint = adjustedInput.count - 1 - (filter.count - 1)
        self.complexContext = Array(adjustedInput[contextStartingPoint..<adjustedInput.count])
        
        return SignalTools.downsampleComplex(iqData: adjustedInput, decimationFactor: self.decimationFactor, filter: self.filter)
    }
    
    private func consumeComplexContext() -> [DSPComplex] {
        var returnVal = self.complexContext
        self.complexContext = []
        return returnVal
    }

}

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
