//
//  DSPBackend.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 1/14/26.
//

import Foundation

#if canImport(Accelerate)
import Accelerate
typealias DSPBackend = AccelerateBackend

#else
typealias DSPBackend = GenericBackend

#endif

public enum DSP {
    
    static func convolve(signal: UnsafePointer<Float>, signalStride: Int, kernel: UnsafePointer<Float>, kernelStride: Int, result: UnsafeMutablePointer<Float>, resultStride: Int, outputLength: Int, kernelLength: Int) -> Void {
        DSPBackend.conv(signal, signalStride, kernel, kernelStride, result, resultStride, outputLength, kernelLength)
    }
    
    static func multiplyComplexVectors(input1: UnsafePointer<SplitComplexSignal>, input1Stride: Int, input2: UnsafePointer<SplitComplexSignal>, output: UnsafeMutablePointer<SplitComplexSignal>, count: Int, useConjugate: Bool) -> Void {
        DSPBackend.zvmul(input1, input1Stride, input2, 1, output, 1, count, useConjugate ? 1 : 0)
    }
    
    static func phase(input: UnsafePointer<SplitComplexSignal>, inputStride: Int, output: UnsafeMutablePointer<Float>, outputStride: Int, count: Int) -> Void {
        DSPBackend.zvphas(input, inputStride, output, outputStride, count)
    }
    
    static func normalize(input: UnsafePointer<Float>, inputStride: Int, output: UnsafeMutablePointer<Float>, calculatedMean: UnsafeMutablePointer<Float>, calculatedStdDev: UnsafeMutablePointer<Float>, count: Int) -> Void {
        DSPBackend.normalize(input, inputStride, output, calculatedMean, calculatedStdDev, count)
    }
    
    static func mean(input: UnsafePointer<Float>, inputStride: Int, output: UnsafePointer<Float>, count: Int) {
        DSPBackend.mean(count, input, inputStride, output)
    }
    
    static func indexOfMaximum(input: UnsafePointer<Float>, inputStride: Int, output: UnsafePointer<(Int,Float)>, count: Int) -> Void {
        DSPBackend.indexOfMaximum(input, inputStride, output, count)
    }
    
    
    
    
}
