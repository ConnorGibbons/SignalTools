//
//  SignalToolsTestsFifteen.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 8/12/25.
//

// Putting this here so this code isn't attempted to compile on older macOS versions (need Xcode 16 ((macOS 14.5)) for Swift 6.0)
#if compiler(>=6.0)

import XCTest
import SignalTools

let TEST_DATA_COUNT = 10_000_000
let randomComplexData: [DSPComplex] = .init(repeating: DSPComplex(real: 0.0, imag: 0.0), count: TEST_DATA_COUNT).map {_ in
    return DSPComplex(real: Float.random(in: -1...1), imag: Float.random(in: -1...1))
}
let randomFloatData: [Float] = .init(repeating: 0.0, count: TEST_DATA_COUNT).map { _ in
    return Float.random(in: -1...1)
}

final class SignalToolsTestsFifteen: XCTestCase {
    
    func testFloatNormalizeAndStdDevExtensionsCorrectnessAndPerformance() throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("Must be on macOS 15 to run this test.") }
        
        let floatGenTimer = Timer(name: "Float array generation")
        _ = randomFloatData[0]
        floatGenTimer.stop()
        
        let baselineStdDevTimer = Timer(name: "Calculating std dev with vDSP.standardDeviation()")
        let baselineStdDev = vDSP.standardDeviation(randomFloatData)
        baselineStdDevTimer.stop()
        
        let stdDevTimer = Timer(name: "Calculating std dev with custom .standardDeviation()")
        let stdDev = randomFloatData.standardDeviation()
        stdDevTimer.stop()
        
        XCTAssert(stdDev == baselineStdDev)
    }
    
    func testFloatNormalize() throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("Must be on macOS 15 to run this test.") }
        
        let floatGenTimer = Timer(name: "Float array generation")
        _ = randomFloatData[0]
        floatGenTimer.stop()
        
        let baselineNormalizedTimer = Timer(name: "Calculating normalized vector with vDSP.normalize()")
        let baselineNormalized = vDSP.normalize(randomFloatData)
        baselineNormalizedTimer.stop()
        
        let normalizedTimer = Timer(name: "Calculating normalized vector with custom .normalize()")
        let normalized = randomFloatData.normalize()
        normalizedTimer.stop()
        
        XCTAssert(normalized == baselineNormalized)
    }
    
    func testRealDownsamplerEquivalence() throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("Must be on macOS 15 to run this test.") }
        
        let floatGenTimer = Timer(name: "Float array generation")
        _ = randomFloatData[0]
        floatGenTimer.stop()
        
        let randomDecimationFactor = Int.random(in: 2...100)
        let randomOutputSampleRate = Int.random(in: 100...48000)
        let randomInputSampleRate = randomOutputSampleRate * randomDecimationFactor
        let randomTapsCount = Int.random(in: 3...151) | 1
        print("Decimation factor: \(randomDecimationFactor) \nOutput sample rate: \(randomOutputSampleRate) \nInput sample rate: \(randomInputSampleRate) \nTaps count: \(randomTapsCount)")
        
        let testDataDownsampleFilter = try FIRFilter(type: .lowPass, cutoffFrequency: Double(Double(randomOutputSampleRate) / 2.0), sampleRate: randomInputSampleRate, tapsLength: randomTapsCount)
        
        let downsampleOriginalTimer = Timer(name: "Real Downsampling (original)")
        let downsampledOriginal = downsampleRealOLD(data: randomFloatData, decimationFactor: randomDecimationFactor, filter: testDataDownsampleFilter.getTaps())
        downsampleOriginalTimer.stop()
        
        let downsampleNewTimer = Timer(name: "Real Downsampling (new)")
        let downsampledNew = SignalTools.downsampleReal(data: randomFloatData, decimationFactor: randomDecimationFactor, filter: testDataDownsampleFilter.getTaps())
        downsampleNewTimer.stop()
        
        XCTAssert(SignalTools.valsAreClose(downsampledOriginal, downsampledNew))
    }
    
    func testComplexDownsamplerEquivalence() throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("Must be on macOS 15 to run this test.") }
        
        let complexGenTimer = Timer(name: "DSPComplex array generation")
        _ = randomComplexData[0]
        complexGenTimer.stop()
        
        let randomDecimationFactor = Int.random(in: 2...100)
        let randomOutputSampleRate = Int.random(in: 100...48000)
        let randomInputSampleRate = randomOutputSampleRate * randomDecimationFactor
        let randomTapsCount = Int.random(in: 3...151) | 1
        print("Decimation factor: \(randomDecimationFactor) \nOutput sample rate: \(randomOutputSampleRate) \nInput sample rate: \(randomInputSampleRate) \nTaps count: \(randomTapsCount)")
        
        let testDataDownsampleFilter = try FIRFilter(type: .lowPass, cutoffFrequency: Double(Double(randomOutputSampleRate) / 2.0), sampleRate: randomInputSampleRate, tapsLength: randomTapsCount)
        
        let downsampleOriginalTimer = Timer(name: "Complex Downsampling (original)")
        let downsampledOriginal = downsampleComplexOLD(iqData: randomComplexData, decimationFactor: randomDecimationFactor, filter: testDataDownsampleFilter.getTaps())
        downsampleOriginalTimer.stop()
        
        let downsampleNewTimer = Timer(name: "Complex Downsampling (new)")
        let downsampledNew = SignalTools.downsampleComplex(iqData: randomComplexData, decimationFactor: randomDecimationFactor, filter: testDataDownsampleFilter.getTaps())
        downsampleNewTimer.stop()
        
        XCTAssert(SignalTools.valsAreClose(downsampledOriginal, downsampledNew))
    }
    
}

struct Timer {
    let start: DispatchTime
    let name: String
    
    init(name: String = "") {
        self.name = name
        self.start = DispatchTime.now()
    }
    
    func stop() {
        let end = DispatchTime.now()
        let nanoseconds = end.uptimeNanoseconds - start.uptimeNanoseconds
        let milliseconds = Double(nanoseconds) / 1_000_000
        print("***\(name): \(milliseconds) ms***")
    }
}

func downsampleComplexOLD(iqData: [DSPComplex], decimationFactor: Int, filter: [Float] = [0.5, 0.5]) -> [DSPComplex] {
    guard iqData.count > (filter.count - 1) else { // Less data than is needed to apply the filter, thus no output.
        return []
    }
    // let usableSamplesCount = iqData.count - (filter.count - 1) // Samples with enough proceeding samples to apply the filter.
    // let outputCount = max(usableSamplesCount / decimationFactor, 1)
    
    var returnVector: [DSPComplex]
    var splitComplexData = DSPSplitComplex(realp: .allocate(capacity: iqData.count), imagp: .allocate(capacity: iqData.count))
    defer {
        splitComplexData.realp.deallocate()
        splitComplexData.imagp.deallocate()
    }
    vDSP.convert(interleavedComplexVector: iqData, toSplitComplexVector: &splitComplexData)
    let iBranchBufferPointer = UnsafeBufferPointer(start: splitComplexData.realp, count: iqData.count)
    let qBranchBufferPointer = UnsafeBufferPointer(start: splitComplexData.imagp, count: iqData.count)
    var iBranchDownsampled = vDSP.downsample(iBranchBufferPointer, decimationFactor: decimationFactor, filter: filter)
    var qBranchDownsampled = vDSP.downsample(qBranchBufferPointer, decimationFactor: decimationFactor, filter: filter)
    returnVector = .init(repeating: DSPComplex(real: 0, imag: 0), count: iBranchDownsampled.count)
    return iBranchDownsampled.withUnsafeMutableBufferPointer { iDownsampledBufferPointer in
        qBranchDownsampled.withUnsafeMutableBufferPointer { qDownsampledBufferPointer in
            let splitDownsampledData = DSPSplitComplex(realp: iDownsampledBufferPointer.baseAddress!, imagp: qDownsampledBufferPointer.baseAddress!)
            vDSP.convert(splitComplexVector: splitDownsampledData, toInterleavedComplexVector: &returnVector)
            return returnVector
        }
    }
}

func downsampleRealOLD(data: [Float], decimationFactor: Int, filter: [Float] = [0.5, 0.5]) -> [Float] {
    return vDSP.downsample(data, decimationFactor: decimationFactor, filter: filter)
}


#endif
