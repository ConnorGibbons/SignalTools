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
            let output = self.vDSPBiquad.apply(input: input)
            return output
        }
        
        mutating func apply(input: [T], output: inout [T]) {
            self.vDSPBiquad.apply(input: input, output: &output)
        }
        
    }
    
    static func makeBiquad<T>(_ coefficients: [Double], channelCount: Int, sectionCount: Int, ofType: T.Type) -> (any BiquadFilter<T>)? where T : FloatingPointBiquadFilterable {
        return AccelerateBiquad(coefficients: coefficients, channelCount: channelCount, sectionCount: sectionCount, ofType: ofType)
    }
    
    static func absolute<T: DSPScalar>(_ signal: [T]) -> [T] {
        if let floatSignal = signal as? [Float], let result = vDSP.absolute(floatSignal) as? [T] {
            return result
        } else if let doubleSignal = signal as? [Double], let result = vDSP.absolute(doubleSignal) as? [T] {
            return result
        }
        return signal.map { $0.magnitude }
    }
    
    static func conv(_ signal: UnsafePointer<Float>, _ signalStride: Int, _ kernel: UnsafePointer<Float>, _ kernelStride: Int, _ result: UnsafeMutablePointer<Float>, _ resultStride: Int, _ outputLength: Int, _ kernelLength: Int) -> Void {
        // vDSP_conv requires the kernel pointer to point to the last element when
        // using a negative stride (convolution mode). The caller passes the pointer
        // at element 0, so we offset it here.
        let adjustedKernel = kernelStride < 0 ? kernel + (kernelLength - 1) * abs(kernelStride) : kernel
        vDSP_conv(signal, vDSP_Stride(signalStride), adjustedKernel, vDSP_Stride(kernelStride), result, vDSP_Stride(resultStride), vDSP_Length(outputLength), vDSP_Length(kernelLength))
    }
    
    static func zvmul(_ input1: UnsafePointer<SplitComplexSamples>,_ input1Stride: Int,_ input2: UnsafePointer<SplitComplexSamples>,_ input2Stride: Int,_ output: UnsafeMutablePointer<SplitComplexSamples>,_ outputStride: Int, _ count: Int, _ useConjugate: Int) -> Void {
        vDSP_zvmul(input1, vDSP_Stride(input1Stride), input2, vDSP_Stride(input2Stride), output, vDSP_Stride(outputStride), vDSP_Length(count), Int32(useConjugate))
    }
    
    static func zvmulD(_ input1: UnsafePointer<SplitDoubleComplexSamples>,_ input1Stride: Int,_ input2: UnsafePointer<SplitDoubleComplexSamples>,_ input2Stride: Int,_ output: UnsafeMutablePointer<SplitDoubleComplexSamples>,_ outputStride: Int, _ count: Int, _ useConjugate: Int) -> Void {
        vDSP_zvmulD(input1, vDSP_Stride(input1Stride), input2, vDSP_Stride(input2Stride), output, vDSP_Stride(outputStride), vDSP_Length(count), Int32(useConjugate))
    }
    
    static func multiply<T: DSPScalar>(_ input1: [T],_ input2: [T],_ result: inout [T]) {
        if var floatResult = result as? [Float], let f1 = input1 as? [Float], let f2 = input2 as? [Float] {
            vDSP.multiply(f1, f2, result: &floatResult)
            result = floatResult as! [T]
        } else if var doubleResult = result as? [Double], let d1 = input1 as? [Double], let d2 = input2 as? [Double] {
            vDSP.multiply(d1, d2, result: &doubleResult)
            result = doubleResult as! [T]
        }
    }
    
    static func multiply(_ input1: SplitComplexSamples,_ input2: SplitComplexSamples,_ count: Int,_ useConjugate: Bool, _ result: inout SplitComplexSamples) {
        vDSP.multiply(input1,by: input2, count: count, useConjugate: useConjugate, result: &result)
    }
    
    static func multiply<T: DSPScalar>(_ scalar: T,_ input: [T]) -> [T] {
        if let floatScalar = scalar as? Float, let floatInput = input as? [Float], let result = vDSP.multiply(floatScalar, floatInput) as? [T] {
            return result
        } else if let doubleScalar = scalar as? Double, let doubleInput = input as? [Double], let result = vDSP.multiply(doubleScalar, doubleInput) as? [T] {
            return result
        }
        return input.map { $0 * scalar }
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
    
    static func magnitude(_ input: [ComplexSample]) -> [Float] {
        var output: [Float] = .init(repeating: 0.0, count: input.count)
        var splitBuffer: SplitComplexSamples = .init(realp: .allocate(capacity: input.count), imagp: .allocate(capacity: input.count))
        defer {
            splitBuffer.realp.deallocate()
            splitBuffer.imagp.deallocate()
        }
        AccelerateBackend.convert(input, &splitBuffer)
        vDSP_zvabs(&splitBuffer, vDSP_Stride(1), &output, vDSP_Stride(1), vDSP_Length(input.count))
        return output
    }
    
    static func maxvi(_ input: UnsafePointer<Float>,_ inputStride: Int,_ outputValue: UnsafeMutablePointer<Float>,_ outputIndex: UnsafeMutablePointer<Int>,_ count: Int) {
        var index: vDSP_Length = 0
        vDSP_maxvi(input, vDSP_Stride(inputStride), outputValue, &index, vDSP_Length(count))
        outputIndex.pointee = Int(index)
    }
    
    static func indexOfMaximum<T: DSPScalar>(_ input: [T]) -> (UInt, T) {
        if let floatInput = input as? [Float], let result = vDSP.indexOfMaximum(floatInput) as? (UInt, T) {
            return result
        } else if let doubleInput = input as? [Double], let result = vDSP.indexOfMaximum(doubleInput) as? (UInt, T) {
            return result
        }
        guard !input.isEmpty else { return (0, T.zero) }
        var maxVal: T = -T.infinity
        var maxIndex: UInt = 0
        for i in 0..<input.count {
            if input[i] > maxVal {
                maxVal = input[i]
                maxIndex = UInt(i)
            }
        }
        return (maxIndex, maxVal)
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
    
    static func convert(_ complexSplitVector: SplitDoubleComplexSamples,_ interleavedComplexVector: inout [DoubleComplexSample]) {
        vDSP.convert(splitComplexVector: complexSplitVector, toInterleavedComplexVector: &interleavedComplexVector)
    }
    
    static func convert(_ interleavedComplexVector: [DoubleComplexSample],_ complexSplitVector: inout SplitDoubleComplexSamples) {
        vDSP.convert(interleavedComplexVector: interleavedComplexVector, toSplitComplexVector: &complexSplitVector)
    }
    
    static func convertElements(_ of: UnsafeBufferPointer<Float>, _ to: UnsafeMutableBufferPointer<Double>) {
        vDSP_vspdp(of.baseAddress!, 1, to.baseAddress!, 1, vDSP_Length(of.count))
    }
    
    static func convertElements(_ of: UnsafeBufferPointer<Double>, _ to: UnsafeMutableBufferPointer<Float>) {
        vDSP_vdpsp(of.baseAddress!, 1, to.baseAddress!, 1, vDSP_Length(of.count))
    }
    
    static func convertElements(_ of: [Double], _ to: inout [Float]) {
        vDSP.convertElements(of: of, to: &to)
    }
    
    static func convertElements(_ of: [Float], _ to: inout [Double]) {
        vDSP.convertElements(of: of, to: &to)
    }
    
    static func window<T>(_ ofType: T.Type, _ usingSequence: WindowFunction, _ count: Int, _ isHalfWindow: Bool) -> [T] where T : FloatingPointGeneratable {
        vDSP.window(ofType: T.self, usingSequence: usingSequence, count: count, isHalfWindow: isHalfWindow)
    }
    
}
#endif
