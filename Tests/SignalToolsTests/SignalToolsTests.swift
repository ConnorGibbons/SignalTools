import XCTest
import SignalTools

let TEST_DATA_COUNT = 1_000_000
let randomComplexData: [ComplexSample] = .init(repeating: ComplexSample(real: 0.0, imag: 0.0), count: TEST_DATA_COUNT).map {_ in
    return ComplexSample(real: Float.random(in: -1...1), imag: Float.random(in: -1...1))
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
        let dataGenTimer = Timer(name: "Data generation")
        _ = randomComplexData[0].real // Forces Swift to initialize the array (otherwise it will do it during a later call)
        dataGenTimer.stopAndPrintTime()
        
        let slowTimer = Timer(name: "Slow demod")
        _ = demodulateFMSlow(randomComplexData)
        slowTimer.stopAndPrintTime()
        
        let normalTimer = Timer(name: "Normal demod")
        _ = demodulateFM(randomComplexData)
        normalTimer.stopAndPrintTime()
        
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
        let floatGenTimer = Timer(name: "Float array generation")
        _ = randomFloatData[0]
        floatGenTimer.stopAndPrintTime()
        
        let baselineAvgTimer = Timer(name: "Baseline average")
        let baselineAvg = randomFloatData.reduce(0, +) / Float(randomFloatData.count)
        baselineAvgTimer.stopAndPrintTime()
        
        let avgTimer = Timer(name: "Custom average")
        let avg = randomFloatData.average()
        avgTimer.stopAndPrintTime()
        
        XCTAssertEqual(avg, baselineAvg, accuracy: 0.001)
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
        let modulateTimer = Timer(name: "AFSK modulation")
        guard let afskModulated = afskModulate(bits: bitBuffer, baud: 1200, sampleRate: 48000, markFreq: 1300, spaceFreq: 2100) else {
            XCTFail("Could not modulate")
            return
        }
        modulateTimer.stopAndPrintTime()
        
        let demodulateTimer = Timer(name: "AFSK demodulation")
        guard let (afskDemodulated, _) = afskDemodulate(samples: afskModulated, sampleRate: 48000, baud: 1200, markFreq: 1300, spaceFreq: 2100) else {
            XCTFail("Could not demodulate")
            return
        }
        demodulateTimer.stopAndPrintTime()
        
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

        let downsampleTimer = Timer(name: "Downsampling \(TEST_DATA_COUNT) samples (Non-stateful)")
        let downsampledFullPass = SignalTools.downsampleComplex(iqData: testData, decimationFactor: randomDecimationFactor, filter: testDataDownsampleFilter.getTaps())
        downsampleTimer.stopAndPrintTime()
        
        // Don't put too much stock in the time this takes, its got a lot of overhead
        let downsampleTimer2 = Timer(name: "Downsampling \(TEST_DATA_COUNT) samples (stateful)")
        let downsampler = Downsampler(inputSampleRate: randomInputSampleRate, outputSampleRate: randomOutputSampleRate, filter: testDataDownsampleFilter.getTaps())
        let randomlySplitData = randomlySplitArray(testData)
        var downsampledOutput: [ComplexSample] = []
        for split in randomlySplitData {
            let output = downsampler?.downsampleComplex(split)
            downsampledOutput.append(contentsOf: output!)
        }
        downsampleTimer2.stopAndPrintTime()
        
        XCTAssertTrue(valsAreClose(downsampledOutput, downsampledFullPass, threshold: 0.001))
    }
    
}

// MARK: - Helpers

private struct Timer {
    let start: DispatchTime
    let name: String
    
    init(name: String = "") {
        self.name = name
        self.start = DispatchTime.now()
    }
    
    func stop() -> Double {
        let end = DispatchTime.now()
        let nanoseconds = end.uptimeNanoseconds - start.uptimeNanoseconds
        let milliseconds = Double(nanoseconds) / 1_000_000
        return milliseconds
    }
    
    func stopAndPrintTime() {
        let runtime = self.stop()
        print("*** \(name) took \(runtime)ms ***")
    }

}
