//
//  DSPBackend.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 1/14/26.
//

import Foundation

#if canImport(Accelerate)
import Accelerate
enum AccelerateBackend {
    
    static func conv(_ signal: UnsafePointer<Float>, _ signalStride: Int, _ kernel: UnsafePointer<Float>, _ kernelStride: Int, _ result: UnsafeMutablePointer<Float>, _ resultStride: Int, _ outputLength: Int, _ kernelLength: Int) -> Void {
        vDSP_conv(signal, vDSP_Stride(signalStride), kernel, vDSP_Stride(kernelStride), result, vDSP_Stride(resultStride), vDSP_Length(outputLength), vDSP_Length(kernelLength))
    }
    
    static func zvmul(_ input1: UnsafePointer<SplitComplexSamples>,_ input1Stride: Int,_ input2: UnsafePointer<SplitComplexSamples>,_ input2Stride: Int,_ output: UnsafeMutablePointer<SplitComplexSamples>,_ outputStride: Int, _ count: Int, _ useConjugate: Int) -> Void {
        vDSP_zvmul(input1, vDSP_Stride(input1Stride), input2, vDSP_Stride(input2Stride), output, vDSP_Stride(outputStride), vDSP_Length(count), Int32(useConjugate))
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

    static func desamp(_ input: UnsafePointer<Float>,_ decimationFactor: Int,_ filter: UnsafePointer<Float>, _ output: UnsafeMutablePointer<Float>,_ count: Int, _ filterLength: Int) {
        vDSP_desamp(input, vDSP_Stride(decimationFactor), filter, output, vDSP_Length(count), vDSP_Length(filterLength))
    }
    
}
#endif

enum GenericBackend {
    
    /// Performs convolution / correlation on **signal**.
    /// signalStride: Determines how many elements to advance by in **signal** after each calculation. Must be >= 1.
    /// kernel: The values to multiply with to determine each result.
    /// kernelStride: The number of values to advance by in **kernel** after each calculation. Use a negative stride to perform convolution, positive for correlation. Must be != 0.
    /// result: The vector to output results to.
    /// resultStride: Number of elements to advance by after inserting each result.
    /// outputLength: The number of elements expected to be output to **result**.
    /// kernelLength: Number of elements in **kernel**.
    static func conv(_ signal: UnsafePointer<Float>, _ signalStride: Int, _ kernel: UnsafePointer<Float>, _ kernelStride: Int, _ result: UnsafeMutablePointer<Float>, _ resultStride: Int, _ outputLength: Int, _ kernelLength: Int) -> Void {
        guard kernelStride != 0 && signalStride > 0 && resultStride > 0 else {
            print("Invalid parameters for conv")
            assertionFailure(); return
        }
        let isConvolution = kernelStride < 0
        for resultNum in 0..<outputLength {
            var curResult: Float = 0
            var kernelPos = isConvolution ? ((kernelLength - 1) * abs(kernelStride)) : 0
            for i in 0..<kernelLength {
                curResult += signal[signalStride * (resultNum + i)] * kernel[kernelPos]
                kernelPos = kernelPos + kernelStride
            }
            result[resultNum * resultStride] = curResult
        }
    }
    
    /// Performs multiplication on two complex vectors, **input1** and **input2**
    /// input1: The first complex vector
    /// input1Stride: Number of elements to jump between successive multiplications on **input1**
    /// input2: The second complex vector
    /// input2Stride: Number of elements to jump between successive multiplications on **input2**
    /// output: Will be used as the output vector.
    /// outputStride: Determines how many elements to jump after inserting each result.
    /// count: Number of elements from **input1** and **input2** to multiply, equivalent to the number of results.
    /// useConjugate: Determines whether conjugate of input1 will be used. Pass in 1 for conjugate, -1 to not use conjugate.
    static func zvmul(_ input1: UnsafePointer<SplitComplexSamples>,_ input1Stride: Int,_ input2: UnsafePointer<SplitComplexSamples>,_ input2Stride: Int,_ output: UnsafeMutablePointer<SplitComplexSamples>,_ outputStride: Int, _ count: Int, _ useConjugate: Int) -> Void {
        guard input1Stride > 0 && input2Stride > 0 && outputStride > 0 else {
            print("Invalid parameters for zvmul")
            assertionFailure(); return
        }
        for i in 0..<count {
            let input1Pos = input1Stride * i
            let input2Pos = input2Stride * i
            let outputPos = outputStride * i
            let input1Real = input1.pointee.realp[input1Pos]
            let input1Imag = input1.pointee.imagp[input1Pos] * (useConjugate == 1 ? -1.0 : 1.0)
            let input2Real = input2.pointee.realp[input2Pos]
            let input2Imag = input2.pointee.imagp[input2Pos]
            let outputReal = input1Real*input2Real - input1Imag*input2Imag
            let outputImag = input1Real*input2Imag + input1Imag*input2Real
            output.pointee.realp[outputPos] = outputReal
            output.pointee.imagp[outputPos] = outputImag
        }
    }
    
    /// Calculates the phase of each complex vector in **input**
    /// *Note: Output from this function ranges from -pi to pi. For a fully-ranged output, call an unwrapping function like unwrapAngle *
    /// input: Complex input vector
    /// inputStride: Number of elements to jump between successive phase calculations
    /// output: The output vector for phase calculations
    /// outputStride: Number of elements to jump after inserting each result.
    /// count: Number of elements from **input** to calculate phase for.
    static func zvphas(_ input: UnsafePointer<SplitComplexSamples>,_ inputStride: Int,_ output: UnsafeMutablePointer<Float>,_ outputStride: Int,_ count: Int) {
        guard inputStride > 0 && outputStride > 0 else {
            print("Invalid parameters for zvphas")
            assertionFailure(); return
        }
        for i in 0..<count {
            let inputReal = input.pointee.realp[inputStride * i]
            let inputImag = input.pointee.imagp[inputStride * i]
            output[outputStride * i] = atan2(inputImag, inputReal)
        }
    }
    
    /// Standardize the vector **input** to have a mean of 0 and std of 1.
    /// vDSP refers to this is "normalize" which is likely a misnomer.
    /// input: Real-valued input vector
    /// inputStride: Number of elements to jump between successive calculations
    /// output: Real-valued output vector
    /// outputStride: Number of elements to jump after inserting each result
    /// calculatedMean: Mean of the vector **input** -- this is output by the normalize function, its value upon calling does not matter.
    /// calculatedStdDev: Standard deviation of the vector **input** -- this is output by the normalize function, its value upon calling does not matter.
    /// count: Number of elements from **input** to use in standardization.
    static func normalize(_ input: UnsafePointer<Float>,_ inputStride: Int,_ output: UnsafeMutablePointer<Float>,_ outputStride: Int,_ calculatedMean: UnsafeMutablePointer<Float>,_ calculatedStdDev: UnsafeMutablePointer<Float>,_ count: Int) {
        guard inputStride > 0 && outputStride > 0 && count > 0 else {
            print("Invalid parameters for normalize")
            assertionFailure(); return
        }
        var averagePtr: UnsafeMutablePointer<Float> = UnsafeMutablePointer.allocate(capacity: 1); defer { averagePtr.deallocate() }
        GenericBackend.meanv(input, inputStride, averagePtr, count)
        let average = averagePtr.pointee
        calculatedMean.pointee = average
        var sumSquareDeviations: Float = 0.0
        for i in 0..<count {
            sumSquareDeviations += ((input[i*inputStride] - average) * (input[i*inputStride] - average))
        }
        let standardDeviation = sqrt(sumSquareDeviations / Float(count))
        calculatedStdDev.pointee = standardDeviation
        
        for i in 0..<count {
            output[i * outputStride] = (input[i * inputStride] - average) / standardDeviation
        }
    }
    
    /// Calculates the mean value of the **input** vector.
    /// input: Real-valued input vector
    /// inputStride: Number of elements to jump between successive calculations
    /// output: Real-valued output vector
    /// count: Number of elements from **input** to use to calculate the mean.
    static func meanv(_ input: UnsafePointer<Float>,_ inputStride: Int,_ output: UnsafeMutablePointer<Float>,_ count: Int) {
        guard inputStride > 0 && count > 0 else {
            print("Invalid parameters for meanv")
            assertionFailure(); return
        }
        var sum: Float = 0.0
        for i in 0..<count {
            let currVal = input[i*inputStride]
            sum += currVal
        }
        output.pointee = sum / Float(count)
    }
    
    /// Find the max value in the **input** vector and its index.
    /// input: Real-valued input vector
    /// inputStride: Number of elements to jump between successive checks.
    /// outputValue: The maximum value found in **input**
    /// outputIndex: Index at which **outputValue** occurs in **input**
    /// count: Number of elements from **input** to check when looking for max value.
    static func maxvi(_ input: UnsafePointer<Float>,_ inputStride: Int,_ outputValue: UnsafeMutablePointer<Float>,_ outputIndex: UnsafeMutablePointer<Int>,_ count: Int) {
        guard inputStride > 0 && count > 0 else {
            print("Invalid parameters for maxvi")
            assertionFailure(); return
        }
        var max: Float = -Float.infinity
        var maxIndex: Int = 0
        for i in 0..<count {
            let currVal = input[i*inputStride]
            if currVal > max {
                max = currVal
                maxIndex = i
            }
        }
        outputValue.pointee = max
        outputIndex.pointee = maxIndex
    }
    
    /// Downsamples & filters the **input** vector.
    /// input: Real-valued input vector
    /// decimationFactor: The amount by which the total number of samples is divided. For example, a decimation factor of two implies the sample count will be halved.
    /// filter: The FIR filter taps to filter each taken value with.
    /// output: The resulting decimated vector will be placed here.
    /// count: The number of output elements to generate.
    /// filterLength: Number of elements in **filter**
    /// Note: Be careful with "count" and the actual length of input. **input** needs at least (**count** - 1) x **decimationFactor ** + **filterLength** samples or the function will attempt to access OOB memory and crash.
    static func desamp(_ input: UnsafePointer<Float>,_ decimationFactor: Int,_ filter: UnsafePointer<Float>, _ output: UnsafeMutablePointer<Float>,_ count: Int, _ filterLength: Int) {
        guard decimationFactor > 0 && count > 0 && filterLength > 0 else {
            print("Invalid parameters for desamp")
            assertionFailure(); return
        }
        for i in 0..<count {
            var currSum: Float = 0.0
            let startIndex = i*decimationFactor
            for n in 0..<filterLength {
                currSum += input[startIndex + n] * filter[n]
            }
            output[i] = currSum
        }
    }
    
}

#if canImport(Accelerate)
typealias DSPBackend = AccelerateBackend
#else
typealias DSPBackend = GenericBackend
#endif

public enum DSP {
    
    /// Performs either correlation or convolution on two real single-precision vectors.
    /// Provide a negative stride on the filter to do convolution, positive for correlation.
    static func convolve(_ signal: UnsafePointer<Float>,_ signalStride: Int,_ kernel: UnsafePointer<Float>,_ kernelStride: Int,_ result: UnsafeMutablePointer<Float>,_ resultStride: Int, _ outputLength: Int,_ kernelLength: Int) -> Void {
        DSPBackend.conv(signal, signalStride, kernel, kernelStride, result, resultStride, outputLength, kernelLength)
    }
    
    static func multiplyComplexVectors(_ input1: UnsafePointer<SplitComplexSamples>,_ input1Stride: Int,_ input2: UnsafePointer<SplitComplexSamples>,_ input2Stride: Int,_ output: UnsafeMutablePointer<SplitComplexSamples>,_ outputStride: Int,_ count: Int,_ useConjugate: Bool) -> Void {
        DSPBackend.zvmul(input1, input1Stride, input2, input2Stride, output, outputStride, count, useConjugate ? 1 : -1)
    }
    
    static func phase(_ input: UnsafePointer<SplitComplexSamples>,_ inputStride: Int,_ output: UnsafeMutablePointer<Float>,_ outputStride: Int,_ count: Int) -> Void {
        DSPBackend.zvphas(input, inputStride, output, outputStride, count)
    }
    
    static func normalize(_ input: UnsafePointer<Float>,_ inputStride: Int,_ output: UnsafeMutablePointer<Float>,_ outputStride: Int,_ calculatedMean: UnsafeMutablePointer<Float>,_ calculatedStdDev: UnsafeMutablePointer<Float>,_ count: Int) -> Void {
        DSPBackend.normalize(input, inputStride, output, outputStride, calculatedMean, calculatedStdDev, count)
    }
    
    static func mean(_ input: UnsafePointer<Float>,_ inputStride: Int,_ output: UnsafeMutablePointer<Float>,_ count: Int) {
        DSPBackend.meanv(input, inputStride, output, count)
    }
    
    static func maxValueIndex(_ input: UnsafePointer<Float>,_ inputStride: Int,_ outputValue: UnsafeMutablePointer<Float>,_ outputIndex: UnsafeMutablePointer<Int>,_ count: Int) -> Void {
        DSPBackend.maxvi(input, inputStride, outputValue, outputIndex, count)
    }
    
}
