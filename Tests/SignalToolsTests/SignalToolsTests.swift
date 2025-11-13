import XCTest
import SignalTools
import Accelerate

let TEST_DATA_COUNT = 1_000_000
let randomComplexData: [DSPComplex] = .init(repeating: DSPComplex(real: 0.0, imag: 0.0), count: TEST_DATA_COUNT).map {_ in
    return DSPComplex(real: Float.random(in: -1...1), imag: Float.random(in: -1...1))
}
let randomFloatData: [Float] = .init(repeating: 0.0, count: TEST_DATA_COUNT).map { _ in
    return Float.random(in: -1...1)
}

let TEST_BITS_COUNT = 100_000
let randomBinaryData: [UInt8] = .init(repeating: 0, count: TEST_BITS_COUNT).map { _ in
    return UInt8.random(in: 0...1)
}

class SignalToolsTests: XCTestCase {
    
    func testTimeFMDemodulation() throws {
        let t0_dataGen = Date.timeIntervalSinceReferenceDate
        _ = randomComplexData[0].real // Forces Swift to initialize the array (otherwise it will do it during a later call)
        let t1_dataGen = Date.timeIntervalSinceReferenceDate
        print("Data generatrion took: \(t1_dataGen - t0_dataGen) s")
        
        let t0_slow = Date.timeIntervalSinceReferenceDate
        _ = demodulateFMSlow(randomComplexData)
        let t1_slow = Date.timeIntervalSinceReferenceDate
        print("Slow demod took: \(t1_slow - t0_slow) s")
        
        let t0_normal = Date.timeIntervalSinceReferenceDate
        _ = demodulateFM(randomComplexData)
        let t1_normal = Date.timeIntervalSinceReferenceDate
        print("Normal demod took: \(t1_normal - t0_normal) s")
        
        XCTAssert(true)
    }
    
    func testFMDemodulationEquivalence() throws {
        let slowFMDemodulated = demodulateFMSlow(randomComplexData)
        let normalFMDemodulated = demodulateFM(randomComplexData)
        for i in 0..<100 {
            XCTAssert(abs(normalFMDemodulated[i] - slowFMDemodulated[i]) < 0.01)
        }
    }
    
    func testFloatAverageExtensionCorrectnessAndPerformance() throws {
        let t0_floatGen = Date.timeIntervalSinceReferenceDate
        _ = randomFloatData[0]
        let t1_floatGen = Date.timeIntervalSinceReferenceDate
        print("Float array generation took: \(t1_floatGen - t0_floatGen) s")
        
        let t0_baselineAvg = Date.timeIntervalSinceReferenceDate
        let baselineAvg = vDSP.mean(randomFloatData)
        let t1_baseLineAvg = Date.timeIntervalSinceReferenceDate
        print("Calculating average (\(baselineAvg)) with vDSP.average() took: \(t1_baseLineAvg - t0_baselineAvg)")
        
        let t0_avg = Date.timeIntervalSinceReferenceDate
        let avg = randomFloatData.average()
        let t1_avg = Date.timeIntervalSinceReferenceDate
        print("Calculating average (\(avg)) with custom .average() took: \(t1_avg - t0_avg)")
        
        XCTAssert(avg == baselineAvg)
    }
    
    func testBitBuffer() throws {
        var bitBuffer = BitBuffer()
        var bitStringFromArray = ""
        for bit in randomBinaryData {
            bitBuffer.append(bit)
            bitStringFromArray += String(bit)
        }
        XCTAssert(bitStringFromArray == bitBuffer.getBitstring())
        for bitIndex in 0..<randomBinaryData.count {
            XCTAssert(bitBuffer[bitIndex] == randomBinaryData[bitIndex])
        }
    }
    
    func testAFSK() throws {
        var bitBuffer = BitBuffer()
        for bit in randomBinaryData {
            bitBuffer.append(bit)
        }
        let modulate_t0 = Date.timeIntervalSinceReferenceDate
        guard let afskModulated = afskModulate(bits: bitBuffer, baud: 1200, sampleRate: 48000, markFreq: 1300, spaceFreq: 2100) else {
            XCTFail("Could not modulate")
            return
        }
        let modulate_t1 = Date.timeIntervalSinceReferenceDate
        print("Time to modulate AFSK: \(modulate_t1 - modulate_t0) seconds")
        
        let demodulate_t0 = Date.timeIntervalSinceReferenceDate
        guard let (afskDemodulated, _) = afskDemodulate(samples: afskModulated, sampleRate: 48000, baud: 1200, markFreq: 1300, spaceFreq: 2100) else {
            XCTFail("Could not demodulate")
            return
        }
        let demodulate_t1 = Date.timeIntervalSinceReferenceDate
        print("Time to demodulate AFSK: \(demodulate_t1 - demodulate_t0) seconds")
        
        for i in 0..<randomBinaryData.count {
            XCTAssert(afskDemodulated[i] == bitBuffer[i])
            if(afskDemodulated[i] != bitBuffer[i]) {
                print("Discrepancy: \(i) [expected: \(bitBuffer[i]), actual: \(afskDemodulated[i])]")
            }
        }
    }
    
    func testTopKIndices() {
        let testArr1: [Float] = [0.0, 11.1, 5.5, 3.3, 2.0, 1.5, 9.3] // Top order: 1, 6, 2, 3, 4, 5, 0
        XCTAssert(testArr1.topKIndices(1) == [1])
        XCTAssert(testArr1.topKIndices(2) == [1,6])
        XCTAssert(testArr1.topKIndices(3) == [1,6,2])
        XCTAssert(testArr1.topKIndices(4) == [1,6,2,3])
        XCTAssert(testArr1.topKIndices(5) == [1,6,2,3,4])
        XCTAssert(testArr1.topKIndices(6) == [1,6,2,3,4,5])
        XCTAssert(testArr1.topKIndices(0) == [])
    }
    
    func testCorrelation() {
        // Example from Apple for vDSP_conv
        let signal: [Float] = [1,2,3,4,5,6,7,8]
        let template: [Float] = [10,20,30]
        let expectedResult: [Float] = [140.0, 200.0, 260.0, 320.0, 380.0, 440.0]
        let result = SignalTools.slidingCorrelation(signal: signal, template: template)
        XCTAssert(result == expectedResult)
        
        var signalBitBuffer = BitBuffer()
        for bit in [0,1,1,1,0,1,0,0,0,1,1] {
            signalBitBuffer.append(UInt8(bit))
        }
        var templateBitBuffer = BitBuffer()
        for bit in [0,1,0] {
            templateBitBuffer.append(UInt8(bit))
        }
        
        let signalAsFloatArr = signalBitBuffer.asFloatArray()
        let templateAsFloatArr = templateBitBuffer.asFloatArray()
        // peak should be at index 4, since that's where signal & template perfectly match
        guard let bitCorrelationResult = SignalTools.slidingCorrelation(signal: signalAsFloatArr, template: templateAsFloatArr) else { XCTFail("Correlation failed."); return }
        XCTAssert(bitCorrelationResult.topKIndices(1)[0] == 4)
    }
    
    func testRealDownsamplerEquivalence() throws {
        let testData = randomFloatData
        let randomDecimationFactor = Int.random(in: 2...100)
        let randomOutputSampleRate = Int.random(in: 100...48000)
        let randomInputSampleRate = randomOutputSampleRate * randomDecimationFactor
        let randomTapsCount: Int
        randomTapsCount = Int.random(in: 3...151) | 1
        print("Decimation factor: \(randomDecimationFactor) \nOutput sample rate: \(randomOutputSampleRate) \nInput sample rate: \(randomInputSampleRate) \nTaps count: \(randomTapsCount)")
        let testDataDownsampleFilter = try FIRFilter(type: .lowPass, cutoffFrequency: Double(Double(randomOutputSampleRate) / 2.0), sampleRate: randomInputSampleRate, tapsLength: randomTapsCount)
        let downsampledFullPass = SignalTools.downsampleReal(data: testData, decimationFactor: randomDecimationFactor, filter: testDataDownsampleFilter.getTaps())
        let downsampler = Downsampler(inputSampleRate: randomInputSampleRate, outputSampleRate: randomOutputSampleRate, filter: testDataDownsampleFilter.getTaps())
        let randomlySplitData = randomlySplitArray(testData)
        var downsampledOutput: [Float] = []
        for split in randomlySplitData {
            let output = downsampler?.downsampleReal(split)
            downsampledOutput.append(contentsOf: output!)
        }
        
        XCTAssertTrue(valsAreClose(downsampledOutput, downsampledFullPass, threshold: 0.00001))
    }
    
    func testComplexDownsamplerEquivalence() throws {
        let testData = randomComplexData
        let randomDecimationFactor = Int.random(in: 2...100)
        let randomOutputSampleRate = Int.random(in: 100...48000)
        let randomInputSampleRate = randomOutputSampleRate * randomDecimationFactor
        let randomTapsCount = Int.random(in: 3...151) | 1
        print("Decimation factor: \(randomDecimationFactor) \nOutput sample rate: \(randomOutputSampleRate) \nInput sample rate: \(randomInputSampleRate) \nTaps count: \(randomTapsCount)")
        
        let testDataDownsampleFilter = try FIRFilter(type: .lowPass, cutoffFrequency: Double(Double(randomOutputSampleRate) / 2.0), sampleRate: randomInputSampleRate, tapsLength: randomTapsCount)
        
//        let downsampledOriginal = SignalTools.downsampleComplexOLD(iqData: testData, decimationFactor: randomDecimationFactor, filter: testDataDownsampleFilter.getTaps())
        let downsampledFullPass = SignalTools.downsampleComplex(iqData: testData, decimationFactor: randomDecimationFactor, filter: testDataDownsampleFilter.getTaps())
        let downsampler = Downsampler(inputSampleRate: randomInputSampleRate, outputSampleRate: randomOutputSampleRate, filter: testDataDownsampleFilter.getTaps())
        let randomlySplitData = randomlySplitArray(testData)
        var downsampledOutput: [DSPComplex] = []
        for split in randomlySplitData {
            let output = downsampler?.downsampleComplex(split)
            downsampledOutput.append(contentsOf: output!)
        }
        
        print(downsampledOutput.count)
        
        XCTAssertTrue(valsAreClose(downsampledOutput, downsampledFullPass, threshold: 0.001))
    }
    
}

func randomlySplitArray<T>(_ array: [T]) -> [[T]] {
    guard array.count > 1 else { return [array] }
    
    // Decide how many cuts to make (0 up to array.count - 1)
    let numberOfCuts = Int.random(in: 0...(array.count - 1))
    var cutIndices: Set<Int> = []
    
    // Generate unique random cut indices
    while cutIndices.count < numberOfCuts {
        cutIndices.insert(Int.random(in: 1..<array.count))
    }
    
    let sortedCuts = cutIndices.sorted()
    var result: [[T]] = []
    var start = 0
    
    for cut in sortedCuts {
        result.append(Array(array[start..<cut]))
        start = cut
    }
    result.append(Array(array[start..<array.count]))
    
    return result
}

func valsAreClose(_ arr1: [Float], _ arr2: [Float], threshold: Float = 0.001) -> Bool {
    guard arr1.count == arr2.count else { return false }
    for i in 0..<arr1.count {
        if abs(arr1[i] - arr2[i]) > threshold {
            return false
        }
    }
    return true
}

func valsAreClose(_ arr1: [DSPComplex],_ arr2: [DSPComplex], threshold: Float = 0.001) -> Bool {
    guard arr1.count == arr2.count else { return false }
    for i in 0..<arr1.count {
        if abs(arr1[i].imag - arr2[i].imag) > threshold {
            return false
        }
        if abs(arr1[i].real - arr2[i].real) > threshold {
            return false
        }
    }
    return true
}
