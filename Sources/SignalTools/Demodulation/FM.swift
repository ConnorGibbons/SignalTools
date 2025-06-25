//
//  FM.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 6/24/25.
//
//  Code for demodulating signals modulated using frequency modulation.

import Foundation
import Accelerate

/// This function will do FM demodulation, but much slower than demodulateFM or demodulateFMAlt
/// Here for conceptual understanding.
public func demodulateFMSlow(_ samples: [DSPComplex]) -> [Float] {
    var diffs =  [Float].init(repeating: 0.0, count: samples.count - 1)
    for i in 1..<samples.count {
        let i0 = samples[i-1].real
        let q0 = samples[i-1].imag
        let i1 = samples[i].real
        let q1 = samples[i].imag
        
        let realPart = (i1 * i0) + (q1 * q0)
        let imaginaryPart = (q1 * i0) - (q0 * i1)
        diffs[i - 1] = atan2(imaginaryPart, realPart)
    }
    return diffs
}

/// Demodulates FM by mutliplying each sample by the conjugate of the preceding sample, providing phase in radians.
public func demodulateFM(_ samples: [DSPComplex]) -> [Float] {
    let n = vDSP_Length(samples.count - 1)
    var diffs = [Float].init(repeating: 0.0, count: samples.count - 1)
    samples.withUnsafeBufferPointer { samplesPtr in
        let basePointer = samplesPtr.baseAddress!
        basePointer.withMemoryRebound(to: Float.self, capacity: 2 * samples.count) { ptr in
            let i0 = UnsafePointer(ptr)
            let q0 = UnsafePointer(ptr.advanced(by: 1))
            let i1 = UnsafePointer(ptr.advanced(by: 2))
            let q1 = UnsafePointer(ptr.advanced(by: 3))
            var tempReal = [Float].init(repeating: 0.0, count: samples.count - 1)
            var tempIm = [Float].init(repeating: 0.0, count: samples.count - 1)
            
            let stride = vDSP_Stride(2) // One IQSample struct's worth of memory should be 2 floats
            let shortStride = vDSP_Stride(1)
            tempReal.withUnsafeMutableBufferPointer { tempRealPtr in
                tempIm.withUnsafeMutableBufferPointer { tempImPtr in
                    var A: DSPSplitComplex = .init(realp: UnsafeMutablePointer(mutating: i0), imagp: UnsafeMutablePointer(mutating: q0)) // prev
                    var B: DSPSplitComplex = .init(realp: UnsafeMutablePointer(mutating: i1), imagp: UnsafeMutablePointer(mutating: q1)) // curr
                    var C: DSPSplitComplex = .init(realp: tempRealPtr.baseAddress!, imagp: tempImPtr.baseAddress!)
                    vDSP_zvmul(&A, stride, &B, stride, &C, 1, n, -1)
                    vDSP_zvphas(&C, shortStride, &diffs, shortStride, n)
                }
            }
        }
    }
    return diffs
}
