//
//  AccelerateBackend.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 2/19/26.
//

#if canImport(Accelerate)
import Accelerate

//protocol BiquadFilter<T> {
//    associatedtype T: FloatingPointBiquadFilterable
//    init?(coefficients: [Double], channelCount: Int, sectionCount: Int, ofType: T.Type)
//    mutating func apply(input: [T]) -> [T]
//}

enum AccelerateBackend: Backend {
    
    /// AccelerateBackend wrapper for vDSP.Biquad
    struct AccelerateBiquad<T>: BiquadFilter where T: FloatingPointBiquadFilterable {
        var vDSPBiquad: vDSP.Biquad<T>
        
        init?(coefficients: [Double], channelCount: Int, sectionCount: Int, ofType: T.Type) {
            guard let vDSPBQuad = vDSP.Biquad(coefficients: coefficients, channelCount: vDSP_Length(channelCount), sectionCount: vDSP_Length(sectionCount), ofType: ofType) else { return nil }
            self.vDSPBiquad = vDSPBQuad
        }
        
        mutating func apply(input: [T]) -> [T] {
            var output = self.vDSPBiquad.apply(input: input)
            return output
        }
    }
    
    static func makeBiquad<T>(_ coefficients: [Double], channelCount: Int, sectionCount: Int, ofType: T.Type) -> (any BiquadFilter<T>)? where T : FloatingPointBiquadFilterable {
        return AccelerateBiquad(coefficients: coefficients, channelCount: channelCount, sectionCount: sectionCount, ofType: ofType)
    }
    
    static func conv(_ signal: UnsafePointer<Float>, _ signalStride: Int, _ kernel: UnsafePointer<Float>, _ kernelStride: Int, _ result: UnsafeMutablePointer<Float>, _ resultStride: Int, _ outputLength: Int, _ kernelLength: Int) -> Void {
        vDSP_conv(signal, vDSP_Stride(signalStride), kernel, vDSP_Stride(kernelStride), result, vDSP_Stride(resultStride), vDSP_Length(outputLength), vDSP_Length(kernelLength))
    }
    
    static func zvmul(_ input1: UnsafePointer<SplitComplexSamples>,_ input1Stride: Int,_ input2: UnsafePointer<SplitComplexSamples>,_ input2Stride: Int,_ output: UnsafeMutablePointer<SplitComplexSamples>,_ outputStride: Int, _ count: Int, _ useConjugate: Int) -> Void {
        vDSP_zvmul(input1, vDSP_Stride(input1Stride), input2, vDSP_Stride(input2Stride), output, vDSP_Stride(outputStride), vDSP_Length(count), Int32(useConjugate))
    }
    
    static func multiply(_ input1: [Float],_ input2: [Float],_ result: inout [Float]) {
        vDSP.multiply(input1, input2, result: &result)
    }
    
    static func multiply(_ input1: SplitComplexSamples,_ input2: SplitComplexSamples,_ count: Int,_ useConjugate: Bool, _ result: inout SplitComplexSamples) {
        vDSP.multiply(input1,by: input2, count: count, useConjugate: useConjugate, result: &result)
    }
    
    static func multiply(_ scalar: Float,_ input: [Float]) -> [Float] {
        vDSP.multiply(scalar, input)
    }
    
    static func zvphas(_ input: UnsafePointer<SplitComplexSamples>,_ inputStride: Int,_ output: UnsafeMutablePointer<Float>,_ outputStride: Int,_ count: Int) {
        vDSP_zvphas(input, vDSP_Stride(inputStride), output, vDSP_Stride(outputStride), vDSP_Length(count))
    }
    
    static func normalize(_ input: UnsafePointer<Float>,_ inputStride: Int,_ output: UnsafeMutablePointer<Float>,_ outputStride: Int,_ calculatedMean: UnsafeMutablePointer<Float>,_ calculatedStdDev: UnsafeMutablePointer<Float>,_ count: Int) {
        vDSP_normalize(input, vDSP_Stride(inputStride), output, vDSP_Stride(outputStride), calculatedMean, calculatedStdDev, vDSP_Length(count))
    }
    
    static func meanv(_ input: UnsafePointer<Float>,_ inputStride: Int,_ output: UnsafeMutablePointer<Float>,_ count: Int) {
        vDSP_meanv(input, vDSP_Stride(inputStride), output, vDSP_Length(count))
    }
    
    static func maxvi(_ input: UnsafePointer<Float>,_ inputStride: Int,_ outputValue: UnsafeMutablePointer<Float>,_ outputIndex: UnsafeMutablePointer<Int>,_ count: Int) {
        var index: vDSP_Length = 0
        vDSP_maxvi(input, vDSP_Stride(inputStride), outputValue, &index, vDSP_Length(count))
        outputIndex.pointee = Int(index)
    }
    
    static func indexOfMaximum(_ input: [Float]) -> (UInt, Float) {
        return vDSP.indexOfMaximum(input)
    }
    
    static func desamp(_ input: UnsafePointer<Float>,_ decimationFactor: Int,_ filter: UnsafePointer<Float>, _ output: UnsafeMutablePointer<Float>,_ count: Int, _ filterLength: Int) {
        vDSP_desamp(input, vDSP_Stride(decimationFactor), filter, output, vDSP_Length(count), vDSP_Length(filterLength))
    }
    
    static func convert(_ complexSplitVector: SplitComplexSamples,_ interleavedComplexVector: inout [ComplexSample]) {
        vDSP.convert(splitComplexVector: complexSplitVector, toInterleavedComplexVector: &interleavedComplexVector)
    }
    
    static func convert(_ interleavedComplexVector: [ComplexSample],_ complexSplitVector: inout SplitComplexSamples) {
        vDSP.convert(interleavedComplexVector: interleavedComplexVector, toSplitComplexVector: &complexSplitVector)
    }
    
    static func window<T>(_ ofType: T, _ usingSequence: WindowFunction, _ count: Int, _ isHalfWindow: Bool) -> [T] where T : FloatingPointGeneratable {
        vDSP.window(ofType: T.self, usingSequence: usingSequence, count: count, isHalfWindow: isHalfWindow)
    }
    
}
#endif
