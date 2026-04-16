//
//  BackendComparisonTests.swift
//  SignalTools
//
//  Compares AccelerateBackend and GenericBackend for equivalence and runtime.
//
//  Note: Don't fully trust these tests just yet. I wrote them w/ AI, and I can already tell that there are issues where the data is lazily generated prior to the Accelerate tests, causing them to
//  look very slow compared to their generic Swift counterparts.


#if canImport(Accelerate)

import XCTest
import Accelerate
@testable import SignalTools

// MARK: - Test Data

let BC_FLOAT_COUNT = 100_000
let bcRandomFloatData: [Float] = (0..<BC_FLOAT_COUNT).map { _ in Float.random(in: -1...1) }
let bcRandomFloatData2: [Float] = (0..<BC_FLOAT_COUNT).map { _ in Float.random(in: -1...1) }
let bcRandomDoubleData: [Double] = (0..<BC_FLOAT_COUNT).map { _ in Double.random(in: -1...1) }
// Touched below in setUp to ensure arrays are fully materialized before timing starts.

let BC_COMPLEX_COUNT = 100_000
let bcRandomComplexData: [ComplexSample] = (0..<BC_COMPLEX_COUNT).map { _ in
    ComplexSample(real: Float.random(in: -1...1), imag: Float.random(in: -1...1))
}
let bcRandomDoubleComplexData: [DoubleComplexSample] = (0..<BC_COMPLEX_COUNT).map { _ in
    DoubleComplexSample(real: Double.random(in: -1...1), imag: Double.random(in: -1...1))
}
// Touched below in setUp to ensure arrays are fully materialized before timing starts.


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
}

private func printComparison(_ name: String, accelerateMs: Double, genericMs: Double) {
    let speedup = genericMs / accelerateMs
    let paddedName = name.padding(toLength: 40, withPad: " ", startingAt: 0)
    print("  \(paddedName)  Accelerate: \(String(format: "%8.3f", accelerateMs)) ms  Generic: \(String(format: "%8.3f", genericMs)) ms  Speedup: \(String(format: "%.1f", speedup))x")
}

/// Allocates an empty SplitComplexSamples of the given count.
/// Caller must deallocate realp and imagp.
private func makeEmptySplitComplex(count: Int) -> SplitComplexSamples {
    let realp = UnsafeMutablePointer<Float>.allocate(capacity: count)
    let imagp = UnsafeMutablePointer<Float>.allocate(capacity: count)
    realp.initialize(repeating: 0, count: count)
    imagp.initialize(repeating: 0, count: count)
    return SplitComplexSamples(realp: realp, imagp: imagp)
}

/// Allocates an empty SplitDoubleComplexSamples of the given count.
/// Caller must deallocate realp and imagp.
private func makeEmptySplitDoubleComplex(count: Int) -> SplitDoubleComplexSamples {
    let realp = UnsafeMutablePointer<Double>.allocate(capacity: count)
    let imagp = UnsafeMutablePointer<Double>.allocate(capacity: count)
    realp.initialize(repeating: 0, count: count)
    imagp.initialize(repeating: 0, count: count)
    return SplitDoubleComplexSamples(realp: realp, imagp: imagp)
}

private func deallocate(_ split: SplitComplexSamples) {
    split.realp.deallocate()
    split.imagp.deallocate()
}

private func deallocate(_ split: SplitDoubleComplexSamples) {
    split.realp.deallocate()
    split.imagp.deallocate()
}

// MARK: - Tests

class BackendComparisonTests: XCTestCase {
    
    let floatTolerance: Float = 1e-4
    let doubleTolerance: Double = 1e-10
    
    /// Force all global test data arrays to fully materialize before any test runs.
    /// Without this, the first test to access each array pays the generation cost in its timing.
    override class func setUp() {
        super.setUp()
        _ = bcRandomFloatData.last
        _ = bcRandomFloatData2.last
        _ = bcRandomDoubleData.last
        _ = bcRandomComplexData.last
        _ = bcRandomDoubleComplexData.last
    }
    
    // MARK: conv
    
    func testConv() {
        let signalCount = 100
        let kernelCount = 101
        let signal = Array(bcRandomFloatData.prefix(signalCount + kernelCount - 1))
        let kernel = Array(bcRandomFloatData2.prefix(kernelCount))
        let outputCount = signalCount
        
        var accelResult = [Float](repeating: 0, count: outputCount)
        var genericResult = [Float](repeating: 0, count: outputCount)
        
        let tAccel = Timer(name: "conv Accelerate")
        signal.withUnsafeBufferPointer { sigPtr in
            kernel.withUnsafeBufferPointer { kernPtr in
                AccelerateBackend.conv(sigPtr.baseAddress!, 1, kernPtr.baseAddress!, -1, &accelResult, 1, outputCount, kernelCount)
            }
        }
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer(name: "conv Generic")
        signal.withUnsafeBufferPointer { sigPtr in
            kernel.withUnsafeBufferPointer { kernPtr in
                GenericBackend.conv(sigPtr.baseAddress!, 1, kernPtr.baseAddress!, -1, &genericResult, 1, outputCount, kernelCount)
            }
        }
        let genericMs = tGeneric.stop()
        
        printComparison("conv", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<outputCount {
            XCTAssertEqual(accelResult[i], genericResult[i], accuracy: floatTolerance, "conv mismatch at index \(i)")
        }
    }
    
    // MARK: zvmul
    
    func testZvmul() {
        let count = BC_COMPLEX_COUNT
        let reversedComplexData = bcRandomComplexData.reversed() as [ComplexSample]
        var splitA1 = makeEmptySplitComplex(count: count)
        var splitB1 = makeEmptySplitComplex(count: count)
        var accelOut = makeEmptySplitComplex(count: count)
        DSP.convert(interleavedComplexVector: bcRandomComplexData, toSplitComplexVector: &splitA1)
        DSP.convert(interleavedComplexVector: reversedComplexData, toSplitComplexVector: &splitB1)
        
        var splitA2 = makeEmptySplitComplex(count: count)
        var splitB2 = makeEmptySplitComplex(count: count)
        var genericOut = makeEmptySplitComplex(count: count)
        DSP.convert(interleavedComplexVector: bcRandomComplexData, toSplitComplexVector: &splitA2)
        DSP.convert(interleavedComplexVector: reversedComplexData, toSplitComplexVector: &splitB2)
        
        defer {
            deallocate(splitA1); deallocate(splitB1); deallocate(accelOut)
            deallocate(splitA2); deallocate(splitB2); deallocate(genericOut)
        }
        
        let tAccel = Timer()
        AccelerateBackend.zvmul(&splitA1, 1, &splitB1, 1, &accelOut, 1, count, 1)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        GenericBackend.zvmul(&splitA2, 1, &splitB2, 1, &genericOut, 1, count, 1)
        let genericMs = tGeneric.stop()
        
        printComparison("zvmul (no conjugate)", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<count {
            XCTAssertEqual(accelOut.realp[i], genericOut.realp[i], accuracy: floatTolerance, "zvmul real mismatch at \(i)")
            XCTAssertEqual(accelOut.imagp[i], genericOut.imagp[i], accuracy: floatTolerance, "zvmul imag mismatch at \(i)")
        }
    }
    
    func testZvmulConjugate() {
        let count = BC_COMPLEX_COUNT
        let reversedComplexData = bcRandomComplexData.reversed() as [ComplexSample]
        var splitA1 = makeEmptySplitComplex(count: count)
        var splitB1 = makeEmptySplitComplex(count: count)
        var accelOut = makeEmptySplitComplex(count: count)
        DSP.convert(interleavedComplexVector: bcRandomComplexData, toSplitComplexVector: &splitA1)
        DSP.convert(interleavedComplexVector: reversedComplexData, toSplitComplexVector: &splitB1)
        
        var splitA2 = makeEmptySplitComplex(count: count)
        var splitB2 = makeEmptySplitComplex(count: count)
        var genericOut = makeEmptySplitComplex(count: count)
        DSP.convert(interleavedComplexVector: bcRandomComplexData, toSplitComplexVector: &splitA2)
        DSP.convert(interleavedComplexVector: reversedComplexData, toSplitComplexVector: &splitB2)
        
        defer {
            deallocate(splitA1); deallocate(splitB1); deallocate(accelOut)
            deallocate(splitA2); deallocate(splitB2); deallocate(genericOut)
        }
        
        let tAccel = Timer()
        AccelerateBackend.zvmul(&splitA1, 1, &splitB1, 1, &accelOut, 1, count, -1)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        GenericBackend.zvmul(&splitA2, 1, &splitB2, 1, &genericOut, 1, count, -1)
        let genericMs = tGeneric.stop()
        
        printComparison("zvmul (conjugate)", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<count {
            XCTAssertEqual(accelOut.realp[i], genericOut.realp[i], accuracy: floatTolerance, "zvmul conj real mismatch at \(i)")
            XCTAssertEqual(accelOut.imagp[i], genericOut.imagp[i], accuracy: floatTolerance, "zvmul conj imag mismatch at \(i)")
        }
    }
    
    // MARK: zvmulD
    
    func testZvmulD() {
        let count = BC_COMPLEX_COUNT
        let reversedDoubleComplexData = bcRandomDoubleComplexData.reversed() as [DoubleComplexSample]
        var splitA1 = makeEmptySplitDoubleComplex(count: count)
        var splitB1 = makeEmptySplitDoubleComplex(count: count)
        var accelOut = makeEmptySplitDoubleComplex(count: count)
        DSP.convert(interleavedComplexVector: bcRandomDoubleComplexData, toSplitComplexVector: &splitA1)
        DSP.convert(interleavedComplexVector: reversedDoubleComplexData, toSplitComplexVector: &splitB1)
        
        var splitA2 = makeEmptySplitDoubleComplex(count: count)
        var splitB2 = makeEmptySplitDoubleComplex(count: count)
        var genericOut = makeEmptySplitDoubleComplex(count: count)
        DSP.convert(interleavedComplexVector: bcRandomDoubleComplexData, toSplitComplexVector: &splitA2)
        DSP.convert(interleavedComplexVector: reversedDoubleComplexData, toSplitComplexVector: &splitB2)
        
        defer {
            deallocate(splitA1); deallocate(splitB1); deallocate(accelOut)
            deallocate(splitA2); deallocate(splitB2); deallocate(genericOut)
        }
        
        let tAccel = Timer()
        AccelerateBackend.zvmulD(&splitA1, 1, &splitB1, 1, &accelOut, 1, count, -1)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        GenericBackend.zvmulD(&splitA2, 1, &splitB2, 1, &genericOut, 1, count, -1)
        let genericMs = tGeneric.stop()
        
        printComparison("zvmulD (conjugate)", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<count {
            XCTAssertEqual(accelOut.realp[i], genericOut.realp[i], accuracy: doubleTolerance, "zvmulD real mismatch at \(i)")
            XCTAssertEqual(accelOut.imagp[i], genericOut.imagp[i], accuracy: doubleTolerance, "zvmulD imag mismatch at \(i)")
        }
    }
    
    // MARK: multiply (real vectors)
    
    func testMultiplyRealVectors() {
        var accelResult = [Float](repeating: 0, count: BC_FLOAT_COUNT)
        var genericResult = [Float](repeating: 0, count: BC_FLOAT_COUNT)
        
        let tAccel = Timer()
        AccelerateBackend.multiply(bcRandomFloatData, bcRandomFloatData2, &accelResult)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        GenericBackend.multiply(bcRandomFloatData, bcRandomFloatData2, &genericResult)
        let genericMs = tGeneric.stop()
        
        printComparison("multiply (real vectors)", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<BC_FLOAT_COUNT {
            XCTAssertEqual(accelResult[i], genericResult[i], accuracy: floatTolerance, "multiply real mismatch at \(i)")
        }
    }
    
    // MARK: multiply (split complex)
    
    func testMultiplySplitComplex() {
        let count = BC_COMPLEX_COUNT
        let reversedComplexData = bcRandomComplexData.reversed() as [ComplexSample]
        var input1 = makeEmptySplitComplex(count: count)
        var input2 = makeEmptySplitComplex(count: count)
        DSP.convert(interleavedComplexVector: bcRandomComplexData, toSplitComplexVector: &input1)
        DSP.convert(interleavedComplexVector: reversedComplexData, toSplitComplexVector: &input2)
        var accelResult = makeEmptySplitComplex(count: count)
        var genericResult = makeEmptySplitComplex(count: count)
        
        defer {
            deallocate(input1); deallocate(input2)
            deallocate(accelResult); deallocate(genericResult)
        }
        
        let tAccel = Timer()
        AccelerateBackend.multiply(input1, input2, count, true, &accelResult)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        GenericBackend.multiply(input1, input2, count, true, &genericResult)
        let genericMs = tGeneric.stop()
        
        printComparison("multiply (split complex)", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<count {
            XCTAssertEqual(accelResult.realp[i], genericResult.realp[i], accuracy: floatTolerance, "multiply split real mismatch at \(i)")
            XCTAssertEqual(accelResult.imagp[i], genericResult.imagp[i], accuracy: floatTolerance, "multiply split imag mismatch at \(i)")
        }
    }
    
    // MARK: multiply (scalar)
    
    func testMultiplyScalar() {
        let scalar: Float = 3.14159
        
        let tAccel = Timer()
        let accelResult = AccelerateBackend.multiply(scalar, bcRandomFloatData)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        let genericResult = GenericBackend.multiply(scalar, bcRandomFloatData)
        let genericMs = tGeneric.stop()
        
        printComparison("multiply (scalar)", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<BC_FLOAT_COUNT {
            XCTAssertEqual(accelResult[i], genericResult[i], accuracy: floatTolerance, "multiply scalar mismatch at \(i)")
        }
    }
    
    // MARK: zvphas
    
    func testZvphas() {
        let count = BC_COMPLEX_COUNT
        var split1 = makeEmptySplitComplex(count: count)
        var split2 = makeEmptySplitComplex(count: count)
        DSP.convert(interleavedComplexVector: bcRandomComplexData, toSplitComplexVector: &split1)
        DSP.convert(interleavedComplexVector: bcRandomComplexData, toSplitComplexVector: &split2)
        var accelResult = [Float](repeating: 0, count: count)
        var genericResult = [Float](repeating: 0, count: count)
        
        defer { deallocate(split1); deallocate(split2) }
        
        let tAccel = Timer()
        AccelerateBackend.zvphas(&split1, 1, &accelResult, 1, count)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        GenericBackend.zvphas(&split2, 1, &genericResult, 1, count)
        let genericMs = tGeneric.stop()
        
        printComparison("zvphas", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<count {
            XCTAssertEqual(accelResult[i], genericResult[i], accuracy: floatTolerance, "zvphas mismatch at \(i)")
        }
    }
    
    // MARK: normalize
    
    func testNormalize() {
        let count = BC_FLOAT_COUNT
        var accelOutput = [Float](repeating: 0, count: count)
        var genericOutput = [Float](repeating: 0, count: count)
        var accelMean: Float = 0
        var accelStdDev: Float = 0
        var genericMean: Float = 0
        var genericStdDev: Float = 0
        
        let tAccel = Timer()
        bcRandomFloatData.withUnsafeBufferPointer { inputPtr in
            AccelerateBackend.normalize(inputPtr.baseAddress!, 1, &accelOutput, 1, &accelMean, &accelStdDev, count)
        }
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        bcRandomFloatData.withUnsafeBufferPointer { inputPtr in
            GenericBackend.normalize(inputPtr.baseAddress!, 1, &genericOutput, 1, &genericMean, &genericStdDev, count)
        }
        let genericMs = tGeneric.stop()
        
        printComparison("normalize", accelerateMs: accelMs, genericMs: genericMs)
        
        XCTAssertEqual(accelMean, genericMean, accuracy: floatTolerance, "normalize mean mismatch")
        XCTAssertEqual(accelStdDev, genericStdDev, accuracy: floatTolerance, "normalize stddev mismatch")
        for i in 0..<count {
            XCTAssertEqual(accelOutput[i], genericOutput[i], accuracy: floatTolerance, "normalize output mismatch at \(i)")
        }
    }
    
    // MARK: meanv
    
    func testMeanv() {
        var accelResult: Float = 0
        var genericResult: Float = 0
        
        let tAccel = Timer()
        bcRandomFloatData.withUnsafeBufferPointer { ptr in
            AccelerateBackend.meanv(ptr.baseAddress!, 1, &accelResult, BC_FLOAT_COUNT)
        }
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        bcRandomFloatData.withUnsafeBufferPointer { ptr in
            GenericBackend.meanv(ptr.baseAddress!, 1, &genericResult, BC_FLOAT_COUNT)
        }
        let genericMs = tGeneric.stop()
        
        printComparison("meanv", accelerateMs: accelMs, genericMs: genericMs)
        
        XCTAssertEqual(accelResult, genericResult, accuracy: floatTolerance, "meanv mismatch")
    }
    
    // MARK: maxvi
    
    func testMaxvi() {
        var accelValue: Float = 0
        var accelIndex: Int = 0
        var genericValue: Float = 0
        var genericIndex: Int = 0
        
        let tAccel = Timer()
        bcRandomFloatData.withUnsafeBufferPointer { ptr in
            AccelerateBackend.maxvi(ptr.baseAddress!, 1, &accelValue, &accelIndex, BC_FLOAT_COUNT)
        }
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        bcRandomFloatData.withUnsafeBufferPointer { ptr in
            GenericBackend.maxvi(ptr.baseAddress!, 1, &genericValue, &genericIndex, BC_FLOAT_COUNT)
        }
        let genericMs = tGeneric.stop()
        
        printComparison("maxvi", accelerateMs: accelMs, genericMs: genericMs)
        
        XCTAssertEqual(accelIndex, genericIndex, "maxvi index mismatch")
        XCTAssertEqual(accelValue, genericValue, accuracy: floatTolerance, "maxvi value mismatch")
    }
    
    // MARK: indexOfMaximum
    
    func testIndexOfMaximum() {
        let tAccel = Timer()
        let accelResult = AccelerateBackend.indexOfMaximum(bcRandomFloatData)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        let genericResult = GenericBackend.indexOfMaximum(bcRandomFloatData)
        let genericMs = tGeneric.stop()
        
        printComparison("indexOfMaximum", accelerateMs: accelMs, genericMs: genericMs)
        
        XCTAssertEqual(accelResult.0, genericResult.0, "indexOfMaximum index mismatch")
        XCTAssertEqual(accelResult.1, genericResult.1, accuracy: floatTolerance, "indexOfMaximum value mismatch")
    }
    
    // MARK: desamp
    
    func testDesamp() {
        let decimationFactor = 10
        let filterLength = 31
        let filter: [Float] = (0..<filterLength).map { _ in Float.random(in: -1...1) }
        let outputCount = (BC_FLOAT_COUNT - filterLength) / decimationFactor + 1
        var accelResult = [Float](repeating: 0, count: outputCount)
        var genericResult = [Float](repeating: 0, count: outputCount)
        
        let tAccel = Timer()
        bcRandomFloatData.withUnsafeBufferPointer { inputPtr in
            filter.withUnsafeBufferPointer { filterPtr in
                AccelerateBackend.desamp(inputPtr.baseAddress!, decimationFactor, filterPtr.baseAddress!, &accelResult, outputCount, filterLength)
            }
        }
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        bcRandomFloatData.withUnsafeBufferPointer { inputPtr in
            filter.withUnsafeBufferPointer { filterPtr in
                GenericBackend.desamp(inputPtr.baseAddress!, decimationFactor, filterPtr.baseAddress!, &genericResult, outputCount, filterLength)
            }
        }
        let genericMs = tGeneric.stop()
        
        printComparison("desamp", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<outputCount {
            XCTAssertEqual(accelResult[i], genericResult[i], accuracy: floatTolerance, "desamp mismatch at \(i)")
        }
    }
    
    // MARK: convert (split → interleaved, Float)
    
    func testConvertSplitToInterleaved() {
        let count = BC_COMPLEX_COUNT
        var split = makeEmptySplitComplex(count: count)
        DSP.convert(interleavedComplexVector: bcRandomComplexData, toSplitComplexVector: &split)
        defer { deallocate(split) }
        
        var accelResult = [ComplexSample](repeating: ComplexSample(real: 0, imag: 0), count: count)
        var genericResult = [ComplexSample](repeating: ComplexSample(real: 0, imag: 0), count: count)
        
        let tAccel = Timer()
        AccelerateBackend.convert(split, &accelResult)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        GenericBackend.convert(split, &genericResult)
        let genericMs = tGeneric.stop()
        
        printComparison("convert (split→interleaved)", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<count {
            XCTAssertEqual(accelResult[i].real, genericResult[i].real, accuracy: floatTolerance, "convert s→i real mismatch at \(i)")
            XCTAssertEqual(accelResult[i].imag, genericResult[i].imag, accuracy: floatTolerance, "convert s→i imag mismatch at \(i)")
        }
    }
    
    // MARK: convert (interleaved → split, Float)
    
    func testConvertInterleavedToSplit() {
        let count = BC_COMPLEX_COUNT
        var accelSplit = makeEmptySplitComplex(count: count)
        var genericSplit = makeEmptySplitComplex(count: count)
        defer { deallocate(accelSplit); deallocate(genericSplit) }
        
        let tAccel = Timer()
        AccelerateBackend.convert(bcRandomComplexData, &accelSplit)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        GenericBackend.convert(bcRandomComplexData, &genericSplit)
        let genericMs = tGeneric.stop()
        
        printComparison("convert (interleaved→split)", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<count {
            XCTAssertEqual(accelSplit.realp[i], genericSplit.realp[i], accuracy: floatTolerance, "convert i→s real mismatch at \(i)")
            XCTAssertEqual(accelSplit.imagp[i], genericSplit.imagp[i], accuracy: floatTolerance, "convert i→s imag mismatch at \(i)")
        }
    }
    
    // MARK: convert (split → interleaved, Double)
    
    func testConvertSplitToInterleavedDouble() {
        let count = BC_COMPLEX_COUNT
        var split = makeEmptySplitDoubleComplex(count: count)
        DSP.convert(interleavedComplexVector: bcRandomDoubleComplexData, toSplitComplexVector: &split)
        defer { deallocate(split) }
        
        var accelResult = [DoubleComplexSample](repeating: DoubleComplexSample(real: 0, imag: 0), count: count)
        var genericResult = [DoubleComplexSample](repeating: DoubleComplexSample(real: 0, imag: 0), count: count)
        
        let tAccel = Timer()
        AccelerateBackend.convert(split, &accelResult)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        GenericBackend.convert(split, &genericResult)
        let genericMs = tGeneric.stop()
        
        printComparison("convert (split→interleaved Double)", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<count {
            XCTAssertEqual(accelResult[i].real, genericResult[i].real, accuracy: doubleTolerance, "convert s→i double real mismatch at \(i)")
            XCTAssertEqual(accelResult[i].imag, genericResult[i].imag, accuracy: doubleTolerance, "convert s→i double imag mismatch at \(i)")
        }
    }
    
    // MARK: convert (interleaved → split, Double)
    
    func testConvertInterleavedToSplitDouble() {
        let count = BC_COMPLEX_COUNT
        var accelSplit = makeEmptySplitDoubleComplex(count: count)
        var genericSplit = makeEmptySplitDoubleComplex(count: count)
        defer { deallocate(accelSplit); deallocate(genericSplit) }
        
        let tAccel = Timer()
        AccelerateBackend.convert(bcRandomDoubleComplexData, &accelSplit)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        GenericBackend.convert(bcRandomDoubleComplexData, &genericSplit)
        let genericMs = tGeneric.stop()
        
        printComparison("convert (interleaved→split Double)", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<count {
            XCTAssertEqual(accelSplit.realp[i], genericSplit.realp[i], accuracy: doubleTolerance, "convert i→s double real mismatch at \(i)")
            XCTAssertEqual(accelSplit.imagp[i], genericSplit.imagp[i], accuracy: doubleTolerance, "convert i→s double imag mismatch at \(i)")
        }
    }
    
    // MARK: convertElements (Float → Double)
    
    func testConvertElementsFloatToDouble() {
        // Array variant
        var accelDoubles = [Double](repeating: 0, count: BC_FLOAT_COUNT)
        var genericDoubles = [Double](repeating: 0, count: BC_FLOAT_COUNT)
        
        let tAccel = Timer()
        AccelerateBackend.convertElements(bcRandomFloatData, &accelDoubles)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        GenericBackend.convertElements(bcRandomFloatData, &genericDoubles)
        let genericMs = tGeneric.stop()
        
        printComparison("convertElements (Float→Double arr)", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<BC_FLOAT_COUNT {
            XCTAssertEqual(accelDoubles[i], genericDoubles[i], accuracy: doubleTolerance, "convertElements F→D mismatch at \(i)")
        }
        
        // Buffer variant
        let accelBuf = UnsafeMutableBufferPointer<Double>.allocate(capacity: BC_FLOAT_COUNT)
        let genericBuf = UnsafeMutableBufferPointer<Double>.allocate(capacity: BC_FLOAT_COUNT)
        defer { accelBuf.deallocate(); genericBuf.deallocate() }
        
        bcRandomFloatData.withUnsafeBufferPointer { floatPtr in
            let tAccel2 = Timer()
            AccelerateBackend.convertElements(floatPtr, accelBuf)
            let accelMs2 = tAccel2.stop()
            
            let tGeneric2 = Timer()
            GenericBackend.convertElements(floatPtr, genericBuf)
            let genericMs2 = tGeneric2.stop()
            
            printComparison("convertElements (Float→Double buf)", accelerateMs: accelMs2, genericMs: genericMs2)
        }
        
        for i in 0..<BC_FLOAT_COUNT {
            XCTAssertEqual(accelBuf[i], genericBuf[i], accuracy: doubleTolerance, "convertElements F→D buf mismatch at \(i)")
        }
    }
    
    // MARK: convertElements (Double → Float)
    
    func testConvertElementsDoubleToFloat() {
        // Array variant
        var accelFloats = [Float](repeating: 0, count: BC_FLOAT_COUNT)
        var genericFloats = [Float](repeating: 0, count: BC_FLOAT_COUNT)
        
        let tAccel = Timer()
        AccelerateBackend.convertElements(bcRandomDoubleData, &accelFloats)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        GenericBackend.convertElements(bcRandomDoubleData, &genericFloats)
        let genericMs = tGeneric.stop()
        
        printComparison("convertElements (Double→Float arr)", accelerateMs: accelMs, genericMs: genericMs)
        
        for i in 0..<BC_FLOAT_COUNT {
            XCTAssertEqual(accelFloats[i], genericFloats[i], accuracy: floatTolerance, "convertElements D→F mismatch at \(i)")
        }
        
        // Buffer variant
        let accelBuf = UnsafeMutableBufferPointer<Float>.allocate(capacity: BC_FLOAT_COUNT)
        let genericBuf = UnsafeMutableBufferPointer<Float>.allocate(capacity: BC_FLOAT_COUNT)
        defer { accelBuf.deallocate(); genericBuf.deallocate() }
        
        bcRandomDoubleData.withUnsafeBufferPointer { doublePtr in
            let tAccel2 = Timer()
            AccelerateBackend.convertElements(doublePtr, accelBuf)
            let accelMs2 = tAccel2.stop()
            
            let tGeneric2 = Timer()
            GenericBackend.convertElements(doublePtr, genericBuf)
            let genericMs2 = tGeneric2.stop()
            
            printComparison("convertElements (Double→Float buf)", accelerateMs: accelMs2, genericMs: genericMs2)
        }
        
        for i in 0..<BC_FLOAT_COUNT {
            XCTAssertEqual(accelBuf[i], genericBuf[i], accuracy: floatTolerance, "convertElements D→F buf mismatch at \(i)")
        }
    }
    
    // MARK: window
    
    func testWindow() {
        let windowSize = 1024
        
        let sequences: [(WindowFunction, String)] = [
            (.hanningNormalized, "hanningNormalized"),
            (.hanningDenormalized, "hanningDenormalized"),
            (.hamming, "hamming"),
            //            (.blackman, "blackman"),
        ]
        
        for (seq, name) in sequences {
            let tAccel = Timer()
            let accelWindow: [Float] = AccelerateBackend.window(Float.self, seq, windowSize, false)
            let accelMs = tAccel.stop()
            
            let tGeneric = Timer()
            let genericWindow: [Float] = GenericBackend.window(Float.self, seq, windowSize, false)
            let genericMs = tGeneric.stop()
            
            printComparison("window (\(name))", accelerateMs: accelMs, genericMs: genericMs)
            
            XCTAssertEqual(accelWindow.count, genericWindow.count, "window \(name) count mismatch")
            for i in 0..<accelWindow.count {
                XCTAssertEqual(accelWindow[i], genericWindow[i], accuracy: floatTolerance, "window \(name) mismatch at \(i)")
            }
        }
        
        // Due to an Accelerate bug, this needs to stay disabled for now.
        // If it gets fixed I'll uncomment this.
        //        let tAccelHalf = Timer()
        //        let accelHalf: [Float] = AccelerateBackend.window(Float.self, .blackman, windowSize, true)
        //        let accelHalfMs = tAccelHalf.stop()
        //
        //        let tGenericHalf = Timer()
        //        let genericHalf: [Float] = GenericBackend.window(Float.self, .blackman, windowSize, true)
        //        let genericHalfMs = tGenericHalf.stop()
        //
        //        printComparison("window (blackman half)", accelerateMs: accelHalfMs, genericMs: genericHalfMs)
        //
        //        XCTAssertEqual(accelHalf.count, genericHalf.count, "half window count mismatch")
        //        for i in 0..<accelHalf.count {
        //            XCTAssertEqual(accelHalf[i], genericHalf[i], accuracy: floatTolerance, "half window mismatch at \(i)")
        //        }
    }
    
    // MARK: magnitude

    func testMagnitude() {
        let tAccel = Timer()
        let accelResult = AccelerateBackend.magnitude(bcRandomComplexData)
        let accelMs = tAccel.stop()

        let tGeneric = Timer()
        let genericResult = GenericBackend.magnitude(bcRandomComplexData)
        let genericMs = tGeneric.stop()

        printComparison("magnitude", accelerateMs: accelMs, genericMs: genericMs)

        XCTAssertEqual(accelResult.count, genericResult.count, "magnitude count mismatch")
        for i in 0..<accelResult.count {
            XCTAssertEqual(accelResult[i], genericResult[i], accuracy: floatTolerance, "magnitude mismatch at \(i)")
        }
    }

    // MARK: makeBiquad
    
    func testBiquad() {
        // Simple second-order lowpass biquad coefficients (1 section)
        let coefficients: [Double] = [
            0.0675, 0.1349, 0.0675, -1.1430, 0.4128
        ]
        let inputSignal: [Float] = Array(bcRandomFloatData.prefix(10_000))
        
        var accelBiquad = AccelerateBackend.makeBiquad(coefficients, channelCount: 1, sectionCount: 1, ofType: Float.self)
        var genericBiquad = GenericBackend.makeBiquad(coefficients, channelCount: 1, sectionCount: 1, ofType: Float.self)
        
        XCTAssertNotNil(accelBiquad, "Failed to create Accelerate biquad")
        XCTAssertNotNil(genericBiquad, "Failed to create Generic biquad")
        
        let tAccel = Timer()
        let accelResult = accelBiquad!.apply(input: inputSignal)
        let accelMs = tAccel.stop()
        
        let tGeneric = Timer()
        let genericResult = genericBiquad!.apply(input: inputSignal)
        let genericMs = tGeneric.stop()
        
        printComparison("biquad (1 section, 10K)", accelerateMs: accelMs, genericMs: genericMs)
        
        XCTAssertEqual(accelResult.count, genericResult.count, "biquad output count mismatch")
        for i in 0..<accelResult.count {
            XCTAssertEqual(accelResult[i], genericResult[i], accuracy: floatTolerance, "biquad mismatch at \(i)")
        }
    }
    
}

#endif
