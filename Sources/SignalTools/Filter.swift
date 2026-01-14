//
//  Filter.swift
//  RTLSDRTesting
//
//  Created by Connor Gibbons  on 4/21/25.
//

public protocol Filter {
    func filteredSignal( _ input: inout [Float])
    func filteredSignal(_ input: inout [ComplexSignal])
}

public enum FilterType {
    case lowPass
}

// Class representing cascading biquad IIR filter
public class IIRFilter: Filter {
    var params: [FilterParameter]
    var biquad: vDSP.Biquad<Float>?
    
    public init() {
        params = []
    }
    
    public func addCustomParams(_ params: [FilterParameter]) -> IIRFilter {
        self.params.append(contentsOf: params)
        biquad = nil
        return self
    }
    
    public func addLowpassFilter(sampleRate: Int, frequency: Double, q: Double) -> IIRFilter {
        params.append(LowPassFilterParameter(sampleRate: Double(sampleRate), frequency: frequency, q: q))
        biquad = nil
        return self
    }
    
    public func addHighpassFilter(sampleRate: Int, frequency: Double, q: Double) -> IIRFilter {
        params.append(HighPassFilterParameter(sampleRate: Double(sampleRate), frequency: frequency, q: q))
        biquad = nil
        return self
    }
    
    public func filteredSignal(_ input: inout [Float]) {
        if biquad == nil {
            initBiquad()
        }
        biquad!.apply(input: input, output: &input)
    }
    
    public func filteredSignal(_ input: inout [ComplexSignal]) {
        if biquad == nil {
            initBiquad()
        }
        var real = [Float].init(repeating: 0.0, count: input.count)
        var imag = [Float].init(repeating: 0.0, count: input.count)
        real.withUnsafeMutableBufferPointer { r in
            imag.withUnsafeMutableBufferPointer { i in
                var splitComplex = DSPSplitComplex(realp: r.baseAddress!, imagp: i.baseAddress!)
                vDSP.convert(interleavedComplexVector: input, toSplitComplexVector: &splitComplex)
            }
        }
        
        biquad!.apply(input: real, output: &real)
        biquad!.apply(input: imag, output: &imag)
        
        real.withUnsafeMutableBufferPointer { r in
            imag.withUnsafeMutableBufferPointer { i in
                let splitComplex = DSPSplitComplex(realp: r.baseAddress!, imagp: i.baseAddress!)
                vDSP.convert(splitComplexVector: splitComplex, toInterleavedComplexVector: &input)
            }
        }
    }
    
    private func flattenParams() -> [Double] {
        var allParams: [Double] = []
        for paramList in params {
            allParams.append(contentsOf: [paramList.b0, paramList.b1, paramList.b2, paramList.a1, paramList.a2])
        }
        return allParams
    }

    private func initBiquad() {
        self.biquad = vDSP.Biquad(coefficients: flattenParams(), channelCount: 1, sectionCount: vDSP_Length(params.count), ofType: Float.self)!
    }
    
}

public class FIRFilter: Filter {
    var taps: [Float]
    var tapsLength: Int
    var stateBuffer: UnsafeMutableBufferPointer<Float> // Last 'tapsLength - 1' values from previous buffer, need for convolution
    var complexStateBuffer: UnsafeMutableBufferPointer<ComplexSignal>
    
    public init(type: FilterType, cutoffFrequency: Double, sampleRate: Int, tapsLength: Int, windowFunc: vDSP.WindowSequence = .hamming) throws {
        var generatedFilter: [Float]
        switch type {
        case .lowPass:
            generatedFilter = makeFIRLowpassTaps(length: tapsLength, cutoff: cutoffFrequency, sampleRate: sampleRate)
        }
        
        taps = generatedFilter
        self.tapsLength = tapsLength
        stateBuffer = .allocate(capacity: tapsLength - 1)
        stateBuffer.initialize(repeating: 0.0)
        complexStateBuffer = .allocate(capacity: tapsLength - 1)
        complexStateBuffer.initialize(repeating: ComplexSignal(real: 0, imag: 0))
    }
    
    public init(taps: [Float]) {
        self.taps = taps
        self.tapsLength = taps.count
        stateBuffer = .allocate(capacity: tapsLength - 1)
        stateBuffer.initialize(repeating: 0.0)
        complexStateBuffer = .allocate(capacity: tapsLength - 1)
        complexStateBuffer.initialize(repeating: ComplexSignal(real: 0, imag: 0))
    }
    
    deinit {
        stateBuffer.deallocate()
        complexStateBuffer.deallocate()
    }
    
    public func filteredSignal(_ input: inout [Float]) {
        let workingBuffer = UnsafeMutableBufferPointer<Float>.allocate(capacity: input.count + tapsLength - 1)
        defer {
            workingBuffer.deallocate()
        }
        
        workingBuffer.baseAddress!.initialize(from: stateBuffer.baseAddress!, count: stateBuffer.count)
        let currentBufferStartingPoint = workingBuffer.baseAddress!.advanced(by: stateBuffer.count)
        currentBufferStartingPoint.initialize(from: input, count: input.count)
        
        copyToStateBuffer(&input)
        var tempOutputBuffer: [Float] = Array(repeating: 0, count: input.count)
        vDSP.convolve(workingBuffer, withKernel: taps, result: &tempOutputBuffer)
        input = tempOutputBuffer
    }
    
    public func filteredSignal(_ input: inout [ComplexSignal]) {
        let workingBuffer = UnsafeMutableBufferPointer<ComplexSignal>.allocate(capacity: input.count + tapsLength - 1)
        defer {
            workingBuffer.deallocate()
        }
        
        workingBuffer.baseAddress!.initialize(from: complexStateBuffer.baseAddress!, count: complexStateBuffer.count)
        let currentBufferStartingPoint = workingBuffer.baseAddress!.advanced(by: stateBuffer.count)
        currentBufferStartingPoint.initialize(from: input, count: input.count)
        
        copyToComplexStateBuffer(&input)
        let splitComplexOutputBuffer = DSPSplitComplex(realp: .allocate(capacity: input.count), imagp: .allocate(capacity: input.count))
        var realOutputBuffer = UnsafeMutableBufferPointer(start: splitComplexOutputBuffer.realp, count: input.count)
        var imagOutputBuffer = UnsafeMutableBufferPointer(start: splitComplexOutputBuffer.imagp, count: input.count)
        var splitComplexBuffer = DSPSplitComplex(realp: .allocate(capacity: input.count + tapsLength - 1), imagp: .allocate(capacity: input.count + tapsLength - 1))
        defer {
            splitComplexOutputBuffer.imagp.deallocate()
            splitComplexOutputBuffer.realp.deallocate()
            splitComplexBuffer.imagp.deallocate()
            splitComplexBuffer.realp.deallocate()
        }
        let splitComplexBufferRealBranchPointer: UnsafeMutableBufferPointer<Float> = .init(start: splitComplexBuffer.realp, count: input.count + tapsLength - 1)
        let splitComplexBufferImagBranchPointer: UnsafeMutableBufferPointer<Float> = .init(start: splitComplexBuffer.imagp, count: input.count + tapsLength - 1)
        vDSP.convert(interleavedComplexVector: workingBuffer.dropLast(0),  toSplitComplexVector: &splitComplexBuffer) // .dropLast(0) converts pointer to array (not sure if this results in a copy)
        vDSP.convolve(splitComplexBufferRealBranchPointer, withKernel: taps, result: &realOutputBuffer)
        vDSP.convolve(splitComplexBufferImagBranchPointer, withKernel: taps, result: &imagOutputBuffer)
        vDSP.convert(splitComplexVector: splitComplexOutputBuffer, toInterleavedComplexVector: &input)
    }
    
    public func filtfilt(_ input: inout [ComplexSignal]) {
        self.filteredSignal(&input)
        var reversedFilteredSignal: [ComplexSignal] = input.reversed()
        let freshFilter = FIRFilter(taps: self.taps)
        freshFilter.filteredSignal(&reversedFilteredSignal)
        input = reversedFilteredSignal.reversed()
    }
    
    public func filtfilt(_ input: inout [Float]) {
        self.filteredSignal(&input)
        var reversedFilteredSignal: [Float] = input.reversed()
        let freshFilter = FIRFilter(taps: self.taps)
        freshFilter.filteredSignal(&reversedFilteredSignal)
        input = reversedFilteredSignal.reversed()
    }

    
    public func getTaps() -> [Float] {
        return self.taps
    }
    
    private func copyToStateBuffer(_ input: inout [Float]) {
        _ = stateBuffer.update(fromContentsOf: input.dropFirst(input.count - tapsLength + 1))
    }
    
    private func copyToComplexStateBuffer(_ input: inout [ComplexSignal]) {
        _ = complexStateBuffer.update(fromContentsOf: input.dropFirst(input.count - tapsLength + 1))
    }
    
}

public class FilterParameter {
    public let b0: Double
    public let b1: Double
    public let b2: Double
    public let a1: Double
    public let a2: Double

    public init(_ b0: Double, _ b1: Double, _ b2: Double, _ a1: Double, _ a2: Double) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.a1 = a1
        self.a2 = a2
    }
    
    public convenience init(_ b0: Double, _ b1: Double, _ b2: Double, _ a0: Double, _ a1: Double, _ a2: Double) {
        self.init(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)
    }
    
    public convenience init(_ params: [Double]) throws {
        if(params.count == 5) {
            self.init(params[0], params[1], params[2], params[3], params[4])
        }
        else if(params.count == 6) {
            self.init(params[0], params[1], params[2], params[3], params[4], params[5])
        }
        else {
            // Will probably just crash :(
            self.init(params[0], params[1], params[2], params[3], params[4])
        }
    }
    
    public func getvDSPBiquad() -> vDSP.Biquad<Float> {
        return vDSP.Biquad(coefficients: [b0, b1, b2, a1, a2], channelCount: 1, sectionCount: 1, ofType: Float.self)!
    }
}

public class LowPassFilterParameter: FilterParameter {
    public init(sampleRate: Double, frequency: Double, q: Double) {
        let w0: Double = 2.0 * Double.pi * frequency / sampleRate
        let alpha: Double = sin(w0) / (2.0 * q)

        let a0: Double = 1.0 + alpha
        let a1: Double = -2.0 * cos(w0)
        let a2: Double = 1.0 - alpha
        let b0: Double = (1.0 - cos(w0)) / 2.0
        let b1: Double = 1.0 - cos(w0)
        let b2: Double = (1.0 - cos(w0)) / 2.0

        super.init(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)
    }
}

public class HighPassFilterParameter: FilterParameter {
    public init(sampleRate: Double, frequency: Double, q: Double) {
        let w0: Double = 2.0 * Double.pi * frequency / sampleRate
        let alpha: Double = sin(w0) / (2.0 * q)

        let a0: Double = 1.0 + alpha
        let a1: Double = -2.0 * cos(w0)
        let a2: Double = 1.0 - alpha
        let b0: Double = (1.0 + cos(w0)) / 2.0
        let b1: Double = -1.0 * (1.0 + cos(w0))
        let b2: Double = (1.0 + cos(w0)) / 2.0

        super.init(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)
    }
}

// Generates a finite impulse response lowpass filter given a cutoff frequency, sampleRate, and optionally a windowing func
public func makeFIRLowpassTaps(length: Int, cutoff: Double, sampleRate: Int, windowSequence: vDSP.WindowSequence = .hamming) -> [Float] {
    let sampleRateAsDouble = Double(sampleRate)
    precondition(length > 0, "Filter length must be > 0")
    precondition(cutoff > 0 && cutoff < sampleRateAsDouble / 2, "Cutoff must be between 0 Hz and Nyquist")
    precondition(length % 2 == 1, "Filter length should be odd")
    let cutoffNormalized = cutoff / sampleRateAsDouble // Now in cycles/sample
    let sincCoeff = 2 * cutoffNormalized
    var sincVals = sinc(count: length, coeff: sincCoeff).map { Float(2 * cutoffNormalized) * Float($0) }
    let window = vDSP.window(ofType: Float.self, usingSequence: windowSequence, count: length, isHalfWindow: false)
    vDSP.multiply(window, sincVals, result: &sincVals)
    let sum = sincVals.reduce(0, +)
    vDSP.divide(sincVals, sum, result: &sincVals)
    return sincVals
}

func sinc(count: Int, coeff: Double) -> [Double] {
    var sincArray: [Double] = .init(repeating: 0, count: count)
    let baseIndex = Int(-Double(count / 2).rounded(.up))
    for i in sincArray.indices {
        sincArray[i] = sinc(x: i + baseIndex, coeff: coeff)
    }
    return sincArray
}

func sinc(x: Int, coeff: Double) -> Double {
    if(x == 0) { return 1.0 }
    else {
        let sincArg = Double.pi * Double(x) * coeff
        return sin(sincArg) / sincArg
    }
}
