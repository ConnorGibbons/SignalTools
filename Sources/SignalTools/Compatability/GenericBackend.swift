//
//  GenericBackend.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 2/19/26.
//
import Foundation

enum GenericBackend: Backend {
//    
//    protocol BiquadFilter<T> {
//        associatedtype T: FloatingPointBiquadFilterable
//        init?(coefficients: [Double], channelCount: Int, sectionCount: Int, ofType: T.Type)
//        mutating func apply(input: [T]) -> [T]
//    }
    
    private struct BiquadState<T> where T: FloatingPointBiquadFilterable {
        var xLine: (T,T) // Stores the previous two values of the input signal. (x[n-1], x[n-2])
        var yLine: (T,T) // Stores the previous two values of the output signal. (y[n-1], y[n-2])
    }
    
    // Direct Form 1 from https://en.wikipedia.org/wiki/Digital_biquad_filter
    private struct BiquadCoefficients {
        // 'b' values are multiplied by the input signal.
        let b0: Double
        let b1: Double
        let b2: Double
        // 'a' values are multiplied by the previously output signal.
        let a1: Double
        let a2: Double
    }
    
    struct SingleChannelGenericBiquad<T> where T: FloatingPointBiquadFilterable {
        private var states: [BiquadState<T>]
        private let coefficients: [BiquadCoefficients]
        
        init?(coefficients: [Double], sectionCount: Int, ofType: T.Type) {
            guard coefficients.count == (5 * sectionCount) else {
                print("SingleChannelGenericBiquad: Coefficients.count must be 5x sectionCount.")
                return nil
            }
            self.states = .init(repeating: BiquadState.init(xLine: (0,0), yLine: (0,0)), count: sectionCount)
            self.coefficients = {
                var coeffs: [BiquadCoefficients] = []
                for i in stride(from: 0, to: coefficients.count, by: 5) {
                    coeffs.append(BiquadCoefficients(b0: coefficients[i], b1: coefficients[i+1], b2: coefficients[i+2], a1: coefficients[i+3], a2: coefficients[i+4]))
                }
                return coeffs
            }()
        }
        
        mutating func apply(input: [T]) -> [T] {
            var outputSignal = input
            for section in 0..<coefficients.count {
                var sectionOutput: [T] = .init(repeating: 0.0, count: outputSignal.count)
                let coeffs = coefficients[section]
                for i in 0..<outputSignal.count {
                    let xLine = states[section].xLine
                    let yLine = states[section].yLine
                    let term1 = T(coeffs.b0) * outputSignal[i]
                    let term2 = T(coeffs.b1) * xLine.0
                    let term3 = T(coeffs.b2) * xLine.1
                    let term4 = T(coeffs.a1) * yLine.0
                    let term5 = T(coeffs.a2) * yLine.1
                    let yCurr = term1 + term2 + term3 - term4 - term5
                    states[section].xLine = (outputSignal[i],xLine.0)
                    states[section].yLine = (yCurr,yLine.0)
                    sectionOutput[i] = yCurr
                }
                outputSignal = sectionOutput
            }
            return outputSignal
        }
    }
    
    struct GenericBiquadFilter<T>: BiquadFilter where T: FloatingPointBiquadFilterable {

        private var channels: [SingleChannelGenericBiquad<T>]
        
        init?(coefficients: [Double], channelCount: Int, sectionCount: Int, ofType: T.Type) {
            self.channels = []
            for _ in 0..<channelCount {
                guard let newFilter = SingleChannelGenericBiquad<T>(coefficients: coefficients, sectionCount: sectionCount, ofType: T.self) else {
                    print("GenericBiquadFilter: Failed to create SingleChannelGenericBiquad")
                    return nil
                }
                channels.append(newFilter)
            }
        }
        
        mutating func apply(input: [T]) -> [T] {
            guard input.count > 0 else { return [] }
            let deinterleavedInput = deinterleaveInput(input: input, channelCount: channels.count)
            guard deinterleavedInput.count == channels.count else {
                print("GenericBiquadFilter: Failed to deinterleave input across \(channels.count) channels.")
                return []
            }
            
            var filteredResults: [[T]] = .init(repeating: [], count: channels.count)
            for channelNum in 0..<channels.count {
                filteredResults[channelNum] = channels[channelNum].apply(input: deinterleavedInput[channelNum])
            }
            return reinterleaveResults(input: filteredResults)
        }
        
        mutating func apply(input: [T], output: inout [T]) {
            output = apply(input: input)
        }
        
        private func deinterleaveInput(input: [T], channelCount: Int) -> [[T]] {
            guard !input.isEmpty && (input.count % channelCount) == 0 && channelCount > 0 else { return [] }
            guard channelCount != 1 else { return [input] }
            var output: [[T]] = Array(repeating: [], count: channelCount)
            let samplesPerChannel = input.count / channelCount
            for j in 0..<channelCount {
                output[j] = .init(repeating: 0.0, count: samplesPerChannel)
            }
            var sampleIndex = 0
            for i in stride(from: 0, to: input.count, by: channelCount) {
                for n in 0..<channelCount {
                    output[n][sampleIndex] = input[i + n]
                }
                sampleIndex += 1
            }
            return output
        }
        
        private func reinterleaveResults(input: [[T]]) -> [T] {
            guard input.count > 1 else { return input.count == 1 ? input[0] : [] }
            let totalSamples = input.reduce(0) { $0 + $1.count }
            var interleavedResult: [T] = .init(repeating: 0.0, count: totalSamples)
            let channelCount = input.count
            for (channel, samples) in input.enumerated() {
                for i in 0..<samples.count {
                    interleavedResult[channel + (i * channelCount)] = samples[i]
                }
            }
            return interleavedResult
        }
    }
    
    static func makeBiquad<T>(_ coefficients: [Double], channelCount: Int, sectionCount: Int, ofType: T.Type) -> (any BiquadFilter<T>)? where T : FloatingPointBiquadFilterable {
        return GenericBiquadFilter(coefficients: coefficients, channelCount: channelCount, sectionCount: sectionCount, ofType: ofType)
    }
    
    static func absolute<T: DSPScalar>(_ signal: [T]) -> [T] {
        return signal.map { $0.magnitude }
    }
    
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
            let input1Imag = input1.pointee.imagp[input1Pos] * (useConjugate == -1 ? -1.0 : 1.0)
            let input2Real = input2.pointee.realp[input2Pos]
            let input2Imag = input2.pointee.imagp[input2Pos]
            let outputReal = input1Real*input2Real - input1Imag*input2Imag
            let outputImag = input1Real*input2Imag + input1Imag*input2Real
            output.pointee.realp[outputPos] = outputReal
            output.pointee.imagp[outputPos] = outputImag
        }
    }
    
    static func zvmulD(_ input1: UnsafePointer<SplitDoubleComplexSamples>,_ input1Stride: Int,_ input2: UnsafePointer<SplitDoubleComplexSamples>,_ input2Stride: Int,_ output: UnsafeMutablePointer<SplitDoubleComplexSamples>,_ outputStride: Int, _ count: Int, _ useConjugate: Int) -> Void {
        guard input1Stride > 0 && input2Stride > 0 && outputStride > 0 else {
            print("Invalid parameters for zvmulD")
            assertionFailure(); return
        }
        for i in 0..<count {
            let input1Pos = input1Stride * i
            let input2Pos = input2Stride * i
            let outputPos = outputStride * i
            let input1Real = input1.pointee.realp[input1Pos]
            let input1Imag = input1.pointee.imagp[input1Pos] * (useConjugate == -1 ? -1.0 : 1.0)
            let input2Real = input2.pointee.realp[input2Pos]
            let input2Imag = input2.pointee.imagp[input2Pos]
            let outputReal = input1Real*input2Real - input1Imag*input2Imag
            let outputImag = input1Real*input2Imag + input1Imag*input2Real
            output.pointee.realp[outputPos] = outputReal
            output.pointee.imagp[outputPos] = outputImag
        }
    }
    
    static func multiply<T: DSPScalar>(_ input1: [T],_ input2: [T],_ result: inout [T]) {
        let shortestLength = min(min(input1.count,input2.count),result.count)
        guard shortestLength > 0 else {
            print("Invalid parameters for multiply")
            assertionFailure(); return
        }
        for i in 0..<shortestLength {
            result[i] = input1[i] * input2[i]
        }
    }
    
    static func multiply(_ input1: SplitComplexSamples,_ input2: SplitComplexSamples,_ count: Int,_ useConjugate: Bool, _ result: inout SplitComplexSamples) {
        guard count > 0 else {
            print("Invalid parameters for multiply")
            assertionFailure(); return
        }
        var mutableInput1 = input1
        var mutableInput2 = input2
        GenericBackend.zvmul(&mutableInput1, 1, &mutableInput2, 1, &result, 1, count, useConjugate ? -1 : 1)
    }
    
    static func multiply<T: DSPScalar>(_ scalar: T,_ input: [T]) -> [T] {
        guard !input.isEmpty else {
            return []
        }
        var result: [T] = .init(repeating: 0, count: input.count)
        for i in 0..<input.count {
            result[i] = input[i] * scalar
        }
        return result
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
        let averagePtr: UnsafeMutablePointer<Float> = UnsafeMutablePointer.allocate(capacity: 1); defer { averagePtr.deallocate() }
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
    
    static func magnitude(_ input: [ComplexSample]) -> [Float] {
        return input.map { $0.magnitude() }
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

    static func indexOfMaximum<T: DSPScalar>(_ input: [T]) -> (UInt, T) {
        guard !input.isEmpty else { return (0, T.zero) }
        var maxVal: T = -T.infinity
        var maxIndex: Int = 0
        for i in 0..<input.count {
            if input[i] > maxVal {
                maxVal = input[i]
                maxIndex = i
            }
        }
        return (UInt(maxIndex), maxVal)
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
    
    /// Converts SplitComplexSamples to [ComplexSample]
    /// complexSplitVector: SplitComplexVector to be converted
    /// interleavedComplexVector: Will store the [ComplexSample] result.
    /// Note: Ensure that complexSplitVector has at least interleavedComplexVector.count elements. Output will only be as long as interleavedComplexVector's length at the time of calling.
    static func convert(_ complexSplitVector: SplitComplexSamples,_ interleavedComplexVector: inout [ComplexSample]) {
        let count = interleavedComplexVector.count
        for i in 0..<count {
            interleavedComplexVector[i] = ComplexSample(real: complexSplitVector.realp[i], imag: complexSplitVector.imagp[i])
        }
    }
    
    static func convert(_ complexSplitVector: SplitDoubleComplexSamples,_ interleavedComplexVector: inout [DoubleComplexSample]) {
        let count = interleavedComplexVector.count
        for i in 0..<count {
            interleavedComplexVector[i] = DoubleComplexSample(real: complexSplitVector.realp[i], imag: complexSplitVector.imagp[i])
        }
    }
    
    /// Converts [ComplexSample] to SplitComplexSamples.
    /// interleavedComplexVector: [ComplexSample] to convert
    /// complexSplitVector: Will store the SplitComplexSamples result.
    /// Note: Make sure that complexSplitVector has memory allocated beforehand, at least enough to store interleavedComplexVector.count in both realp and imagp.
    static func convert(_ interleavedComplexVector: [ComplexSample],_ complexSplitVector: inout SplitComplexSamples) {
        let count = interleavedComplexVector.count
        complexSplitVector.realp.deinitialize(count: count)
        complexSplitVector.imagp.deinitialize(count: count)
        for i in 0..<count {
            complexSplitVector.imagp[i] = interleavedComplexVector[i].imag
            complexSplitVector.realp[i] = interleavedComplexVector[i].real
        }
    }
    
    static func convert(_ interleavedComplexVector: [DoubleComplexSample],_ complexSplitVector: inout SplitDoubleComplexSamples) {
        let count = interleavedComplexVector.count
        complexSplitVector.realp.deinitialize(count: count)
        complexSplitVector.imagp.deinitialize(count: count)
        for i in 0..<count {
            complexSplitVector.imagp[i] = interleavedComplexVector[i].imag
            complexSplitVector.realp[i] = interleavedComplexVector[i].real
        }
    }
    
    static func convertElements(_ of: UnsafeBufferPointer<Float>, _ to: UnsafeMutableBufferPointer<Double>) {
        guard of.count == to.count else {
            print("Can't convert elements: 'of' and 'to' have different counts. (of: \(of.count)  to: \(to.count))")
            return
        }
        for i in 0..<of.count {
            to[i] = Double(of[i])
        }
    }
    
    static func convertElements(_ of: UnsafeBufferPointer<Double>, _ to: UnsafeMutableBufferPointer<Float>) {
        guard of.count == to.count else {
            print("Can't convert elements: 'of' and 'to' have different counts. (of: \(of.count)  to: \(to.count))")
            return
        }
        for i in 0..<of.count {
            to[i] = Float(of[i])
        }
    }
    
    static func convertElements(_ of: [Float], _ to: inout [Double]) {
        guard of.count > 0 else { return }
        if of.count != to.count {
            to = .init(repeating: 0.0, count: of.count)
        }
        for i in 0..<of.count {
            to[i] = Double(of[i])
        }
    }
    
    static func convertElements(_ of: [Double], _ to: inout [Float]) {
        guard of.count > 0 else { return }
        if of.count != to.count {
            to = .init(repeating: 0.0, count: of.count)
        }
        for i in 0..<of.count {
            to[i] = Float(of[i])
        }
    }
    
    static func window<T>(_ ofType: T.Type, _ usingSequence: WindowFunction, _ count: Int, _ isHalfWindow: Bool) -> [T] where T: FloatingPointGeneratable {
        var result: [T]
        switch usingSequence {
        case .hanningNormalized:
            result = hanning(count, normalized: true)
        case .hanningDenormalized:
            result = hanning(count, normalized: false)
        case .hamming:
            result = hamming(count)
        case .blackman:
            result = blackman(count)
        default:
            print("GenericBackend window type \(usingSequence) not implemented, using blackman instead")
            result = blackman(count)
        }
        
        if isHalfWindow {
            // Match vDSP behavior: keep first half, zero out second half
            let halfCount = (count + 1) / 2
            for i in halfCount..<count {
                result[i] = 0
            }
        }
        
        return result
    }
    
    // Math from: https://en.wikipedia.org/wiki/Hann_function
    // vDSP uses N (not N-1) as the period for both normalized and denormalized variants.
    // The normalized variant additionally scales by sqrt(8/3) so the window has unit RMS.
    private static func hanning<T>(_ count: Int, normalized: Bool) -> [T] where T: FloatingPointGeneratable {
        guard count > 0 else { return [] }
        var result: [T] = .init(repeating: 0.0, count: count)
        let N = T(count)
        let scale: T = normalized ? T(sqrt(8.0 / 3.0)) : T(1.0)
        for i in 0..<count {
            let innerVal = (2 * T.pi * T(i)) / N
            let innerValConv: T = T(cos(Double(innerVal)))
            result[i] = scale * T(0.5) * (T(1.0) - innerValConv)
        }
        return result
    }
    
    // Math from: https://en.wikipedia.org/wiki/Window_function#Hamming_window
    // vDSP uses N (not N-1) as the period.
    private static func hamming<T>(_ count: Int) -> [T] where T: FloatingPointGeneratable {
        guard count > 1 else { return count == 1 ? [T(1.0)] : [] }
        var result: [T] = .init(repeating: 0.0, count: count)
        let N = T(count)
        for i in 0..<count {
            let innerVal = (2 * T.pi * T(i)) / N
            let innerValConv: T = T(cos(Double(innerVal)))
            result[i] = T(0.54) - (T(0.46) * innerValConv)
        }
        return result
    }
    
    // Math from: https://en.wikipedia.org/wiki/Window_function#Blackman_window
    // vDSP uses N (not N-1) as the period.
    private static func blackman<T>(_ count: Int) -> [T] where T: FloatingPointGeneratable {
        guard count > 1 else { return count == 1 ? [T(1.0)] : [] }
        var result: [T] = .init(repeating: 0.0, count: count)
        let N = T(count)
        for i in 0..<count {
            let innerVal = (2 * T.pi * T(i)) / N
            let cosVal1: T = T(cos(Double(innerVal)))
            let cosVal2: T = T(cos(Double(2 * innerVal)))
            result[i] = T(0.42) - (T(0.5) * cosVal1) + (T(0.08) * cosVal2)
        }
        return result
    }
    
    
}
