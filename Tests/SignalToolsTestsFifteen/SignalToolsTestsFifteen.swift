//
//  SignalToolsTestsFifteen.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 8/12/25.
//

// Putting this here so this code isn't attempted to compile on older macOS versions (need Xcode 16 ((macOS 14.5)) for Swift 6.0)
#if compiler(>=6.0)

import XCTest
import Accelerate
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
    
    func testFloatNormalize() throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("Must be on macOS 15 to run this test.") }
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

#endif
