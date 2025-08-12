import XCTest
import SignalTools
import Accelerate

let TEST_DATA_COUNT = 10_000_000
let randomComplexData: [DSPComplex] = .init(repeating: DSPComplex(real: 0.0, imag: 0.0), count: TEST_DATA_COUNT).map {_ in
    return DSPComplex(real: Float.random(in: -1...1), imag: Float.random(in: -1...1))
}
let randomFloatData: [Float] = .init(repeating: 0.0, count: TEST_DATA_COUNT).map { _ in
    return Float.random(in: -1...1)
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
    
    @available(macOS 15.0, *)
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
    
    @available(macOS 15.0, *)
    func testFloatNormalizeAndStdDevExtensionsCorrectnessAndPerformance() throws {
        let t0_floatGen = Date.timeIntervalSinceReferenceDate
        _ = randomFloatData[0]
        let t1_floatGen = Date.timeIntervalSinceReferenceDate
        print("Float array generation took: \(t1_floatGen - t0_floatGen) s")
        
        let t0_baselineStdDev = Date.timeIntervalSinceReferenceDate
        let baselineStdDev = vDSP.standardDeviation(randomFloatData)
        let t1_baselineStdDev = Date.timeIntervalSinceReferenceDate
        print("Calculating std dev (\(baselineStdDev)) with vDSP.standardDeviation() took: \(t1_baselineStdDev - t0_baselineStdDev)")
        
        let t0_stdDev = Date.timeIntervalSinceReferenceDate
        let stdDev = randomFloatData.standardDeviation()
        let t1_stdDev = Date.timeIntervalSinceReferenceDate
        print("Calculating std dev (\(stdDev)) with custom .standardDeviation() took: \(t1_stdDev - t0_stdDev)")
        
        XCTAssert(stdDev == baselineStdDev)
    }
    
    @available(macOS 15.0, *)
    func testFloatNormalize() throws {
        let t0_floatGen = Date.timeIntervalSinceReferenceDate
        _ = randomFloatData[0]
        let t1_floatGen = Date.timeIntervalSinceReferenceDate
        print("Float array generation took: \(t1_floatGen - t0_floatGen) s")
        
        let t0_baselineNormalized = Date.timeIntervalSinceReferenceDate
        let baselineNormalized = vDSP.normalize(randomFloatData)
        let t1_baselineNormalized = Date.timeIntervalSinceReferenceDate
        print("Calculating normalized vector with vDSP.normalize() took: \(t1_baselineNormalized - t0_baselineNormalized)")
        
        let t0_normalized = Date.timeIntervalSinceReferenceDate
        let normalized = randomFloatData.normalize()
        let t1_normalized = Date.timeIntervalSinceReferenceDate
        print("Calculating normalized vector with custom .normalize() took: \(t1_normalized - t0_normalized)")
        
        XCTAssert(normalized == baselineNormalized)
    }
    
}
