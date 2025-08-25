import XCTest
import SignalTools
import Accelerate

let TEST_DATA_COUNT = 2_000_000
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
    
}
