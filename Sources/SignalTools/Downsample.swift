//
//  Downsample.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 6/24/25.
//

public class Downsampler {
    private var decimationFactor: Int
    private var filter: [Float]
    
    // State
    private var realContext: [Float]
    private var complexContext: [DSPComplex]
    private var realSkipCount: Int
    private var complexSkipCount: Int
    
    public init?(inputSampleRate: Int, outputSampleRate: Int, filter: [Float]) {
        guard inputSampleRate > outputSampleRate, inputSampleRate % outputSampleRate == 0 else {
            print("inputSampleRate must be an integer multiple of outputSampleRate.")
            return nil
        }
        self.decimationFactor = inputSampleRate / outputSampleRate
        self.realSkipCount = 0
        self.complexSkipCount = 0
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
        self.realSkipCount = 0
        self.complexSkipCount = 0
        do {
            self.filter = try FIRFilter(type: .lowPass, cutoffFrequency: Double(outputSampleRate) / 2.0, sampleRate: inputSampleRate, tapsLength: 15).getTaps()
        }
        catch {
            return nil
        }
        realContext = []
        complexContext = []
    }
    
    public func downsampleReal(_ input: [Float]) -> [Float] {
        let context = consumeRealContext()
        var inputWithContext = context; inputWithContext.append(contentsOf: input)
        var inputWithContextAndPhaseAdjustment = Array(inputWithContext.dropFirst(realSkipCount))
        let usableSampleCount = inputWithContextAndPhaseAdjustment.count - (filter.count - 1)
        let totalSampleCount = inputWithContextAndPhaseAdjustment.count
        guard totalSampleCount >= filter.count else { // Not enough samples, just add context (don't modify phase) and go next
            realContext = inputWithContext
            return []
        }
        
        let expectedOutputCount = Int(ceil(Double(usableSampleCount) / Double(decimationFactor)))
        var output: [Float] = Array(repeating: 0, count: expectedOutputCount)
        let contextStartIndex = inputWithContextAndPhaseAdjustment.count - (filter.count - 1)
        self.realContext = Array(inputWithContextAndPhaseAdjustment[contextStartIndex...])
        
        self.realSkipCount = (expectedOutputCount * decimationFactor) - usableSampleCount // Gets the index of what would be the next sample point, finds what that index would be in the next call w/ buffer prepended. Uses this as the next starting point.
        
        vDSP_desamp(&inputWithContextAndPhaseAdjustment, vDSP_Stride(decimationFactor), &self.filter, &output, vDSP_Length(expectedOutputCount), vDSP_Length(filter.count))
        return output
    }
    
    private func debugPrintWithHighlights(_ arr: [Float], mod: Int) {
        var outputString = "["
        for i in arr.enumerated() {
            if(i.offset % mod == 0) {
                outputString += "**\(i.element)**,"
            } else { outputString += "\(i.element),"}
        }
        outputString += "]"
        print(outputString)
    }
    
    private func consumeRealContext() -> [Float] {
        let returnVal = self.realContext
        self.realContext = []
        return returnVal
    }
    
    public func downsampleComplex(_ input: [DSPComplex]) -> [DSPComplex]? {
        let context = consumeComplexContext()
        var inputWithContext = context; inputWithContext.append(contentsOf: input)
        let inputWithContextAndPhaseAdjustment = Array(inputWithContext.dropFirst(complexSkipCount))
        let usableSampleCount = inputWithContextAndPhaseAdjustment.count - (filter.count - 1)
        let totalSampleCount = inputWithContextAndPhaseAdjustment.count
        
        guard totalSampleCount >= filter.count else { // Not enough samples, just add context (don't modify phase) and go next
            complexContext = inputWithContext
            return []
        }
        
        let expectedOutputCount = Int(ceil(Double(usableSampleCount) / Double(decimationFactor)))
        let contextStartIndex = inputWithContextAndPhaseAdjustment.count - (filter.count - 1)
        self.complexContext = Array(inputWithContextAndPhaseAdjustment[contextStartIndex...])
        
        self.complexSkipCount = (expectedOutputCount * decimationFactor) - usableSampleCount // Gets the index of what would be the next sample point, finds what that index would be in the next call w/ buffer prepended. Uses this as the next starting point.
        
        return SignalTools.downsampleComplex(iqData: inputWithContextAndPhaseAdjustment, decimationFactor: self.decimationFactor, filter: self.filter)
    }
    
    private func consumeComplexContext() -> [DSPComplex] {
        let returnVal = self.complexContext
        self.complexContext = []
        return returnVal
    }
    
}

public func downsampleComplex(iqData: [DSPComplex], decimationFactor: Int, filter: [Float] = [0.5, 0.5]) -> [DSPComplex] {
    guard iqData.count > (filter.count - 1) else { // Less data than is needed to apply the filter, thus no output.
        return []
    }
    
    var returnVector: [DSPComplex]
    var splitComplexData = DSPSplitComplex(realp: .allocate(capacity: iqData.count), imagp: .allocate(capacity: iqData.count))
    defer {
        splitComplexData.realp.deallocate()
        splitComplexData.imagp.deallocate()
    }
    vDSP.convert(interleavedComplexVector: iqData, toSplitComplexVector: &splitComplexData)
    let iBranchBufferPointer = UnsafeBufferPointer(start: splitComplexData.realp, count: iqData.count)
    let qBranchBufferPointer = UnsafeBufferPointer(start: splitComplexData.imagp, count: iqData.count)
    let iBranchArray: [Float] = Array(iBranchBufferPointer)
    let qBranchArray: [Float] = Array(qBranchBufferPointer)
    var iBranchDownsampled = downsampleReal(data: iBranchArray, decimationFactor: decimationFactor, filter: filter)
    var qBranchDownsampled = downsampleReal(data: qBranchArray, decimationFactor: decimationFactor, filter: filter)
    returnVector = .init(repeating: DSPComplex(real: 0, imag: 0), count: iBranchDownsampled.count)
    return iBranchDownsampled.withUnsafeMutableBufferPointer { iDownsampledBufferPointer in
        qBranchDownsampled.withUnsafeMutableBufferPointer { qDownsampledBufferPointer in
            let splitDownsampledData = DSPSplitComplex(realp: iDownsampledBufferPointer.baseAddress!, imagp: qDownsampledBufferPointer.baseAddress!)
            vDSP.convert(splitComplexVector: splitDownsampledData, toInterleavedComplexVector: &returnVector)
            return returnVector
        }
    }
}

public func downsampleReal(data: [Float], decimationFactor: Int, filter: [Float] = [0.5, 0.5]) -> [Float] {
    let usableSampleCount = data.count - (filter.count - 1)
    let outputCount = Int(ceil(Double(usableSampleCount) / Double(decimationFactor)))
    var outputBuffer: [Float] = .init(repeating: 0.0, count: outputCount)
    var dataMutableCopy: [Float] = data
    var filterMutableCopy: [Float] = filter
    
    vDSP_desamp(&dataMutableCopy, vDSP_Stride(decimationFactor), &filterMutableCopy, &outputBuffer, vDSP_Length(outputCount), vDSP_Length(filter.count))
    
    return outputBuffer
}
