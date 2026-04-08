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
    static func absolute(_ signal: [Float]) -> [Float]
    static func conv(_ signal: UnsafePointer<Float>, _ signalStride: Int, _ kernel: UnsafePointer<Float>, _ kernelStride: Int, _ result: UnsafeMutablePointer<Float>, _ resultStride: Int, _ outputLength: Int, _ kernelLength: Int)
    static func zvmul(_ input1: UnsafePointer<SplitComplexSamples>, _ input1Stride: Int, _ input2: UnsafePointer<SplitComplexSamples>, _ input2Stride: Int, _ output: UnsafeMutablePointer<SplitComplexSamples>, _ outputStride: Int, _ count: Int, _ useConjugate: Int)
    static func zvmulD(_ input1: UnsafePointer<SplitDoubleComplexSamples>, _ input1Stride: Int, _ input2: UnsafePointer<SplitDoubleComplexSamples>, _ input2Stride: Int, _ output: UnsafeMutablePointer<SplitDoubleComplexSamples>, _ outputStride: Int, _ count: Int, _ useConjugate: Int)
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
    static func convert(_ complexSplitVector: SplitDoubleComplexSamples, _ interleavedComplexVector: inout [DoubleComplexSample])
    static func convert(_ interleavedComplexVector: [DoubleComplexSample], _ complexSplitVector: inout SplitDoubleComplexSamples)
    static func convertElements(_ of: UnsafeBufferPointer<Float>,_ to: UnsafeMutableBufferPointer<Double>)
    static func convertElements(_ of: UnsafeBufferPointer<Double>,_ to: UnsafeMutableBufferPointer<Float>)
    static func convertElements(_ of: [Float],_ to: inout [Double])
    static func convertElements(_ of: [Double],_ to: inout [Float])
    static func window<T>(_ ofType: T.Type,_ usingSequence: WindowFunction,_ count: Int,_ isHalfWindow: Bool) -> [T] where T: FloatingPointGeneratable
    static func makeBiquad<T>(_ coefficients: [Double], channelCount: Int, sectionCount: Int, ofType: T.Type) -> (any BiquadFilter<T>)? where T: FloatingPointBiquadFilterable
}

// Public facing DSP functions. User shouldn't be using anything defined by the "Backend" protocol directly, it should be wrapped by one of the below functions.
public enum DSP {
    
    /// Returns 'signal' where each element is equal to its absolute value.
    public static func absolute(signal: [Float]) -> [Float] {
        return DSPBackend.absolute(signal)
    }
    
    /// Performs either correlation or convolution on two real single-precision vectors.
    /// Provide a negative stride on the filter to do convolution, positive for correlation.
    public static func convolve(signal: UnsafePointer<Float>, signalStride: Int, kernel: UnsafePointer<Float>, kernelStride: Int, result: UnsafeMutablePointer<Float>, resultStride: Int, outputLength: Int, kernelLength: Int) {
        DSPBackend.conv(signal, signalStride, kernel, kernelStride, result, resultStride, outputLength, kernelLength)
    }
    
    public static func convolve(_ signal: [Float], withKernel: [Float], result: inout [Float]) {
        signal.withUnsafeBufferPointer { signalPtr in
            withKernel.withUnsafeBufferPointer { kernelPtr in
                DSPBackend.conv(signalPtr.baseAddress!, 1, kernelPtr.baseAddress!, -1, &result, 1, result.count, withKernel.count)
            }
        }
    }
    
    public static func convolve(_ signal: UnsafeMutableBufferPointer<Float>, withKernel: [Float], result: UnsafeMutableBufferPointer<Float>) {
        DSPBackend.conv(signal.baseAddress!, 1, withKernel, -1, result.baseAddress!, 1, result.count, withKernel.count)
    }
    
    public static func convolve(_ signal: UnsafeMutableBufferPointer<Float>, withKernel: [Float], result: inout [Float]) {
        DSPBackend.conv(signal.baseAddress!, 1, withKernel, -1, &result, 1, result.count, withKernel.count)
    }
    
    public static func multiplyComplexVectors(input1: UnsafePointer<SplitComplexSamples>, input1Stride: Int, input2: UnsafePointer<SplitComplexSamples>, input2Stride: Int, output: UnsafeMutablePointer<SplitComplexSamples>, outputStride: Int, count: Int, useConjugate: Bool) {
        DSPBackend.zvmul(input1, input1Stride, input2, input2Stride, output, outputStride, count, useConjugate ? -1 : 1)
    }
    
    public static func multiplyComplexVectors(input1: UnsafePointer<SplitDoubleComplexSamples>, input1Stride: Int, input2: UnsafePointer<SplitDoubleComplexSamples>, input2Stride: Int, output: UnsafeMutablePointer<SplitDoubleComplexSamples>, outputStride: Int, count: Int, useConjugate: Bool) {
        DSPBackend.zvmulD(input1, input1Stride, input2, input2Stride, output, outputStride, count, useConjugate ? -1 : 1)
    }
    
    public static func multiplyRealVectors(_ input1: [Float], _ input2: [Float], result: inout [Float]) {
        DSPBackend.multiply(input1, input2, &result)
    }
    
    public static func divideByScalar(_ vector: [Float], scalar: Float, result: inout [Float]) {
        result = DSPBackend.multiply(1/scalar, vector)
    }
    
    public static func multiplyByScalar(_ vector: [Float], scalar: Float, result: inout [Float]) {
        result = DSPBackend.multiply(scalar, vector)
    }
    
    public static func multiplySplitComplexVectors(_ input1: SplitComplexSamples, _ input2: SplitComplexSamples, count: Int, useConjugate: Bool, result: inout SplitComplexSamples) {
        DSPBackend.multiply(input1, input2, count, useConjugate, &result)
    }
    
    public static func phase(input: UnsafePointer<SplitComplexSamples>, inputStride: Int, output: UnsafeMutablePointer<Float>, outputStride: Int, count: Int) {
        DSPBackend.zvphas(input, inputStride, output, outputStride, count)
    }
    
    public static func phase(input: SplitComplexSamples, result: inout [Float]) {
        var tempResult: [Float] = result
        withUnsafePointer(to: input) { inputPtr in
            tempResult.withUnsafeMutableBufferPointer { resultBufferPtr in
                DSPBackend.zvphas(inputPtr, 1, resultBufferPtr.baseAddress!, 1, result.count)
            }
        }
        result = tempResult
    }
    
    public static func normalize(input: UnsafePointer<Float>, inputStride: Int, output: UnsafeMutablePointer<Float>, outputStride: Int, calculatedMean: UnsafeMutablePointer<Float>, calculatedStdDev: UnsafeMutablePointer<Float>, count: Int) {
        DSPBackend.normalize(input, inputStride, output, outputStride, calculatedMean, calculatedStdDev, count)
    }
    
    public static func mean(input: UnsafePointer<Float>, inputStride: Int, output: UnsafeMutablePointer<Float>, count: Int) {
        DSPBackend.meanv(input, inputStride, output, count)
    }
    
    public static func indexOfMaximum(input: UnsafePointer<Float>, inputStride: Int, outputValue: UnsafeMutablePointer<Float>, outputIndex: UnsafeMutablePointer<Int>, count: Int) {
        DSPBackend.maxvi(input, inputStride, outputValue, outputIndex, count)
    }
    
    public static func indexOfMaximum(input: [Float]) -> (UInt, Float) {
        return DSPBackend.indexOfMaximum(input)
    }
    
    public static func desamp(input: UnsafePointer<Float>, decimationFactor: Int, filter: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, count: Int, filterLength: Int) {
        DSPBackend.desamp(input, decimationFactor, filter, output, count, filterLength)
    }
    
    public static func convert(splitComplexVector: SplitComplexSamples, toInterleavedComplexVector: inout [ComplexSample]) {
        DSPBackend.convert(splitComplexVector, &toInterleavedComplexVector)
    }
    
    public static func convert(interleavedComplexVector: [ComplexSample], toSplitComplexVector: inout SplitComplexSamples) {
        DSPBackend.convert(interleavedComplexVector, &toSplitComplexVector)
    }
    
    public static func convert(splitComplexVector: SplitDoubleComplexSamples, toInterleavedComplexVector: inout [DoubleComplexSample]) {
        DSPBackend.convert(splitComplexVector, &toInterleavedComplexVector)
    }
    
    public static func convert(interleavedComplexVector: [DoubleComplexSample], toSplitComplexVector: inout SplitDoubleComplexSamples) {
        DSPBackend.convert(interleavedComplexVector, &toSplitComplexVector)
    }
    
    public static func convertElements(of: [Float], to: inout [Double]) {
        DSPBackend.convertElements(of, &to)
    }
    
    public static func convertElements(of: [Double], to: inout [Float]) {
        DSPBackend.convertElements(of, &to)
    }
    
    public static func convertElements(of: UnsafeBufferPointer<Float>, to: UnsafeMutableBufferPointer<Double>) {
        DSPBackend.convertElements(of, to)
    }
    
    public static func convertElements(of: UnsafeBufferPointer<Double>, to: UnsafeMutableBufferPointer<Float>) {
        DSPBackend.convertElements(of, to)
    }
    
    public static func window<T>(ofType: T.Type, usingSequence: WindowFunction, count: Int, isHalfWindow: Bool) -> [T] where T: FloatingPointGeneratable {
        DSPBackend.window(ofType, usingSequence, count, isHalfWindow)
    }
    
    public static func makeBiquad<T>(coefficients: [Double], channelCount: Int, sectionCount: Int, ofType: T.Type) -> (any BiquadFilter<T>)? where T: FloatingPointBiquadFilterable {
        DSPBackend.makeBiquad(coefficients, channelCount: channelCount, sectionCount: sectionCount, ofType: ofType)
    }
    
}
