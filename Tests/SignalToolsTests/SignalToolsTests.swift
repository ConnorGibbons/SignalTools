import Testing
@testable import SignalTools
import Accelerate

let TEST_DATA_COUNT = 10_000_000
let randomData: [DSPComplex] = .init(repeating: DSPComplex(real: 0.0, imag: 0.0), count: TEST_DATA_COUNT).map {_ in
    return DSPComplex(real: Float.random(in: -1...1), imag: Float.random(in: -1...1))
}

@Test func timeFMDemodulation() async throws {
    let t0_dataGen = Date.timeIntervalSinceReferenceDate
    _ = randomData[0].real // Forces Swift to initialize the array (otherwise it will do it during a later call)
    let t1_dataGen = Date.timeIntervalSinceReferenceDate
    print("Data generatrion took: \(t1_dataGen - t0_dataGen) s")
    
    let t0_slow = Date.timeIntervalSinceReferenceDate
    _ = demodulateFMSlow(randomData)
    let t1_slow = Date.timeIntervalSinceReferenceDate
    print("Slow demod took: \(t1_slow - t0_slow) s")
    
    let t0_normal = Date.timeIntervalSinceReferenceDate
    _ = demodulateFM(randomData)
    let t1_normal = Date.timeIntervalSinceReferenceDate
    print("Normal demod took: \(t1_normal - t0_normal) s")
    
    assert(true)
}

@Test func testFMDemodulationEquivalence() async throws {
    let slowFMDemodulated = demodulateFMSlow(randomData)
    let normalFMDemodulated = demodulateFM(randomData)
    for i in 0..<100 {
        assert(abs(normalFMDemodulated[i] - slowFMDemodulated[i]) < 0.01)
    }
}
