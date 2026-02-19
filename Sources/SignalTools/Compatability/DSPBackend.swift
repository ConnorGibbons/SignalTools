//
//  DSPBackend.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 1/14/26.
//

import Foundation

#if canImport(Accelerate)
typealias DSPBackend = AccelerateBackend
#else
typealias DSPBackend = GenericBackend
#endif

protocol Backend {
    static func conv(_ signal: UnsafePointer<Float>, _ signalStride: Int, _ kernel: UnsafePointer<Float>, _ kernelStride: Int, _ result: UnsafeMutablePointer<Float>, _ resultStride: Int, _ outputLength: Int, _ kernelLength: Int)
    static func zvmul(_ input1: UnsafePointer<SplitComplexSamples>, _ input1Stride: Int, _ input2: UnsafePointer<SplitComplexSamples>, _ input2Stride: Int, _ output: UnsafeMutablePointer<SplitComplexSamples>, _ outputStride: Int, _ count: Int, _ useConjugate: Int)
    static func multiply(_ input1: [Float], _ input2: [Float], _ result: inout [Float])
    static func multiply(_ input1: SplitComplexSamples, _ input2: SplitComplexSamples, _ count: Int, _ useConjugate: Bool, _ result: inout SplitComplexSamples)
    static func multiply(_ scalar: Float, _ input: [Float]) -> [Float]
    static func zvphas(_ input: UnsafePointer<SplitComplexSamples>, _ inputStride: Int, _ output: UnsafeMutablePointer<Float>, _ outputStride: Int, _ count: Int)
    static func normalize(_ input: UnsafePointer<Float>, _ inputStride: Int, _ output: UnsafeMutablePointer<Float>, _ outputStride: Int, _ calculatedMean: UnsafeMutablePointer<Float>, _ calculatedStdDev: UnsafeMutablePointer<Float>, _ count: Int)
    static func meanv(_ input: UnsafePointer<Float>, _ inputStride: Int, _ output: UnsafeMutablePointer<Float>, _ count: Int)
    static func maxvi(_ input: UnsafePointer<Float>, _ inputStride: Int, _ outputValue: UnsafeMutablePointer<Float>, _ outputIndex: UnsafeMutablePointer<Int>, _ count: Int)
    static func indexOfMaximum(_ input: [Float]) -> (UInt, Float)
    static func desamp(_ input: UnsafePointer<Float>, _ decimationFactor: Int, _ filter: UnsafePointer<Float>, _ output: UnsafeMutablePointer<Float>, _ count: Int, _ filterLength: Int)
    static func convert(_ complexSplitVector: SplitComplexSamples, _ interleavedComplexVector: inout [ComplexSample])
    static func convert(_ interleavedComplexVector: [ComplexSample], _ complexSplitVector: inout SplitComplexSamples)
    static func window<T>(_ ofType: T,_ usingSequence: WindowFunction,_ count: Int,_ isHalfWindow: Bool) -> [T] where T: FloatingPointGeneratable
}

public enum DSP {
    
    /// Performs either correlation or convolution on two real single-precision vectors.
    /// Provide a negative stride on the filter to do convolution, positive for correlation.
    static func convolve(signal: UnsafePointer<Float>, signalStride: Int, kernel: UnsafePointer<Float>, kernelStride: Int, result: UnsafeMutablePointer<Float>, resultStride: Int, outputLength: Int, kernelLength: Int) {
        DSPBackend.conv(signal, signalStride, kernel, kernelStride, result, resultStride, outputLength, kernelLength)
    }
    
    static func multiplyComplexVectors(_ input1: UnsafePointer<SplitComplexSamples>, input1Stride: Int, _ input2: UnsafePointer<SplitComplexSamples>, input2Stride: Int, output: UnsafeMutablePointer<SplitComplexSamples>, outputStride: Int, count: Int, useConjugate: Bool) {
        DSPBackend.zvmul(input1, input1Stride, input2, input2Stride, output, outputStride, count, useConjugate ? 1 : -1)
    }
    
    static func multiplyRealVectors(_ input1: [Float], _ input2: [Float], result: inout [Float]) {
        DSPBackend.multiply(input1, input2, &result)
    }
    
    static func multiplySplitComplexVectors(_ input1: SplitComplexSamples, _ input2: SplitComplexSamples, count: Int, useConjugate: Bool, result: inout SplitComplexSamples) {
        DSPBackend.multiply(input1, input2, count, useConjugate, &result)
    }
    
    static func phase(input: UnsafePointer<SplitComplexSamples>, inputStride: Int, output: UnsafeMutablePointer<Float>, outputStride: Int, count: Int) {
        DSPBackend.zvphas(input, inputStride, output, outputStride, count)
    }
    
    static func normalize(input: UnsafePointer<Float>, inputStride: Int, output: UnsafeMutablePointer<Float>, outputStride: Int, calculatedMean: UnsafeMutablePointer<Float>, calculatedStdDev: UnsafeMutablePointer<Float>, count: Int) {
        DSPBackend.normalize(input, inputStride, output, outputStride, calculatedMean, calculatedStdDev, count)
    }
    
    static func mean(input: UnsafePointer<Float>, inputStride: Int, output: UnsafeMutablePointer<Float>, count: Int) {
        DSPBackend.meanv(input, inputStride, output, count)
    }
    
    static func indexOfMaximum(input: UnsafePointer<Float>, inputStride: Int, outputValue: UnsafeMutablePointer<Float>, outputIndex: UnsafeMutablePointer<Int>, count: Int) {
        DSPBackend.maxvi(input, inputStride, outputValue, outputIndex, count)
    }
    
    static func indexOfMaximum(input: [Float]) -> (UInt, Float) {
        return DSPBackend.indexOfMaximum(input)
    }
    
    static func desamp(input: UnsafePointer<Float>, decimationFactor: Int, filter: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, count: Int, filterLength: Int) {
        DSPBackend.desamp(input, decimationFactor, filter, output, count, filterLength)
    }
    
    static func convert(splitComplexVector: SplitComplexSamples, interleavedComplexVector: inout [ComplexSample]) {
        DSPBackend.convert(splitComplexVector, &interleavedComplexVector)
    }
    
    static func convert(interleavedComplexVector: [ComplexSample], splitComplexVector: inout SplitComplexSamples) {
        DSPBackend.convert(interleavedComplexVector, &splitComplexVector)
    }
    
}
