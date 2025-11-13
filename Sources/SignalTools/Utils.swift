//
//  Utils.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 6/24/25.
//

import Accelerate

// Frequency Shifting

public func shiftFrequencyToBaseband(rawIQ: [DSPComplex], result: inout [DSPComplex], frequency: Float, sampleRate: Int) {
    guard rawIQ.count == result.count else {
        return
    }
    
    let sampleCount = rawIQ.count
    let complexMixerArray = (0..<sampleCount).map{ index in
        let angle = -2 * Float.pi * frequency * Float(index) / Float(sampleRate)
        return DSPComplex(real: cos(angle), imag: sin(angle))
    }
    
    var splitInputBuffer = DSPSplitComplex(realp: .allocate(capacity: sampleCount), imagp: .allocate(capacity: sampleCount))
    var splitMixerBuffer = DSPSplitComplex(realp: .allocate(capacity: sampleCount), imagp: .allocate(capacity: sampleCount))
    var splitResultBuffer = DSPSplitComplex(realp: .allocate(capacity: sampleCount), imagp: .allocate(capacity: sampleCount))
    defer {
        splitInputBuffer.realp.deallocate()
        splitInputBuffer.imagp.deallocate()
        splitMixerBuffer.realp.deallocate()
        splitMixerBuffer.imagp.deallocate()
        splitResultBuffer.realp.deallocate()
        splitResultBuffer.imagp.deallocate()
    }
    
    vDSP.convert(interleavedComplexVector: rawIQ, toSplitComplexVector: &splitInputBuffer)
    vDSP.convert(interleavedComplexVector: complexMixerArray, toSplitComplexVector: &splitMixerBuffer)
    vDSP.multiply(splitInputBuffer, by: splitMixerBuffer, count: sampleCount, useConjugate: false, result: &splitResultBuffer)
    vDSP.convert(splitComplexVector: splitResultBuffer, toInterleavedComplexVector: &result)
}

/// I've found that without using Double internally, weird artifacts can occur.
/// Fair warning, this is probably a lot slower than the regular shift to baseband function.
public func shiftFrequencyToBasebandHighPrecision(rawIQ: [DSPComplex], result: inout [DSPComplex], frequency: Float, sampleRate: Int) {
    guard rawIQ.count == result.count else {
        return
    }
    
    let inputBufferAsDoubleComplex = rawIQ.map { DSPDoubleComplex(real: Double($0.real), imag: Double($0.imag)) }
    let sampleCount = rawIQ.count
    let frequenyDouble: Double = Double(frequency)
    let sampleRateDouble: Double = Double(sampleRate)
    let complexMixerArray = (0..<sampleCount).map{ index in
        let angle = -2 * Double.pi * frequenyDouble * Double(index) / sampleRateDouble
        return DSPDoubleComplex(real: cos(angle), imag: sin(angle))
    }
    
    var splitInputBuffer = DSPDoubleSplitComplex(realp: .allocate(capacity: sampleCount), imagp: .allocate(capacity: sampleCount))
    var splitMixerBuffer = DSPDoubleSplitComplex(realp: .allocate(capacity: sampleCount), imagp: .allocate(capacity: sampleCount))
    var splitResultBuffer = DSPDoubleSplitComplex(realp: .allocate(capacity: sampleCount), imagp: .allocate(capacity: sampleCount))
    let splitFloatResultBuffer = DSPSplitComplex(realp: .allocate(capacity: sampleCount), imagp: .allocate(capacity: sampleCount))
    defer {
        splitInputBuffer.realp.deallocate()
        splitInputBuffer.imagp.deallocate()
        splitMixerBuffer.realp.deallocate()
        splitMixerBuffer.imagp.deallocate()
        splitResultBuffer.realp.deallocate()
        splitResultBuffer.imagp.deallocate()
        splitFloatResultBuffer.realp.deallocate()
        splitFloatResultBuffer.imagp.deallocate()
    }
    let splitResultRealBufferPointer: UnsafeBufferPointer<Double> = .init(start: splitResultBuffer.realp, count: sampleCount)
    let splitResultImagBufferPointer: UnsafeBufferPointer<Double> = .init(start: splitResultBuffer.imagp, count: sampleCount)
    var splitFloatResultRealBufferPointer: UnsafeMutableBufferPointer<Float> = .init(start: splitFloatResultBuffer.realp, count: sampleCount)
    var splitFloatResultImagBufferPointer: UnsafeMutableBufferPointer<Float> = .init(start: splitFloatResultBuffer.imagp, count: sampleCount)
    vDSP.convert(interleavedComplexVector: inputBufferAsDoubleComplex, toSplitComplexVector: &splitInputBuffer)
    vDSP.convert(interleavedComplexVector: complexMixerArray, toSplitComplexVector: &splitMixerBuffer)
    vDSP.multiply(splitInputBuffer, by: splitMixerBuffer, count: sampleCount, useConjugate: false, result: &splitResultBuffer)
    vDSP.convertElements(of: splitResultRealBufferPointer, to: &splitFloatResultRealBufferPointer)
    vDSP.convertElements(of: splitResultImagBufferPointer, to: &splitFloatResultImagBufferPointer)
    vDSP.convert(splitComplexVector: splitFloatResultBuffer, toInterleavedComplexVector: &result)
}


// Sample Time / Index Math

public func sampleIndexToTime(_ sampleIndex: Int, sampleRate: Int) -> Double {
    return Double(sampleIndex) / Double(sampleRate)
}

public func timeToSampleIndex(_ time: Double, sampleRate: Int) -> Int {
    return Int(time * Double(sampleRate))
}


// Phase Math

/// Converts per-sample phase differences (radians) to instant frequency
/// rad x sampleRate = radians per second
/// radians per second / 2pi = freq.
public func radToFrequency(radDiffs: [Float], sampleRate: Int) -> [Float] {
    let coefficient = Float(sampleRate) / (2 * Float.pi)
    return vDSP.multiply(coefficient, radDiffs)
}

/// Calculates angle (radians) for each entry in an array of IQ samples.
public func calculateAngle(rawIQ: [DSPComplex], result: inout [Float]) {
    let sampleCount = rawIQ.count
    guard sampleCount == result.count && !rawIQ.isEmpty else {
        return
    }
    var splitBuffer = DSPSplitComplex(realp: .allocate(capacity: sampleCount), imagp: .allocate(capacity: sampleCount))
    vDSP.convert(interleavedComplexVector: rawIQ, toSplitComplexVector: &splitBuffer)
    vDSP.phase(splitBuffer, result: &result)
    
    splitBuffer.realp.deallocate()
    splitBuffer.imagp.deallocate()
}

/// vDSP.phase output has a range of [-pi, pi]
/// If the range is surpassed, it will wrap to the opposite end.
/// Ex. if the value is (real: -1, imag: 0.001) the angle will be roughly pi. Once imag becomes negative, the value jumps to -pi, so we need to add 2pi to account.
public func unwrapAngle(_ angle: inout [Float]) {
    let discontinuityThreshold = Float.pi
    var storedAccumulation: Float = 0
    var index = 1
    var cachedPreviousValue = angle[0]
    while(index < angle.count) {
        if((angle[index] - cachedPreviousValue).magnitude > discontinuityThreshold) {
            if(cachedPreviousValue > angle[index]) {
                storedAccumulation += (2 * discontinuityThreshold)
            }
            else {
                storedAccumulation -= (2 * discontinuityThreshold)
            }
        }
        cachedPreviousValue = angle[index]
        angle[index] = angle[index] + storedAccumulation
        index += 1
    }
}



// --- Random Math / Array Utilities ---

/// Splits an array into a random amount sub-arrays of varying lengths.
public func randomlySplitArray<T>(_ array: [T]) -> [[T]] {
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

/// Determines if all elements at the same index across two arrays are within a provided threshold.
public func valsAreClose(_ arr1: [Float], _ arr2: [Float], threshold: Float = 0.001) -> Bool {
    guard arr1.count == arr2.count else { return false }
    for i in 0..<arr1.count {
        if abs(arr1[i] - arr2[i]) > threshold {
            return false
        }
    }
    return true
}

/// Determines if all elements at the same index across two arrays are within a provided threshold.
public func valsAreClose(_ arr1: [DSPComplex],_ arr2: [DSPComplex], threshold: Float = 0.001) -> Bool {
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
