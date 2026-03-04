//
//  DSPTypes.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 1/14/26.
//

import Foundation

#if canImport(Accelerate)
import Accelerate
public typealias ComplexSample = DSPComplex
public typealias SplitComplexSamples = DSPSplitComplex
public typealias DoubleComplexSample = DSPDoubleComplex
public typealias SplitDoubleComplexSamples = DSPDoubleSplitComplex
public typealias WindowFunction = vDSP.WindowSequence
public typealias FloatingPointGeneratable = vDSP_FloatingPointGeneratable
public typealias FloatingPointBiquadFilterable = vDSP_FloatingPointBiquadFilterable
#else
struct ComplexSample: Equatable {
    var real: Float
    var imag: Float
}

struct SplitComplexSamples {
    var realp: UnsafeMutablePointer<Float>
    var imagp: UnsafeMutablePointer<Float>
}

struct DoubleComplexSample: Equatable {
    var real: Double
    var imag: Double
}

struct SplitDoubleComplexSamples {
    var realp: UnsafeMutablePointer<Double>
    var imagp: UnsafeMutablePointer<Double>
}

enum WindowFunction {
    case hanningNormalized
    case hanningDenormalized
    case hamming
    case blackman
}

protocol FloatingPointGeneratable: BinaryFloatingPoint {}

protocol FloatingPointBiquadFilterable: BinaryFloatingPoint {}
#endif

public extension ComplexSample {
    func magnitude() -> Float {
        return ((real * real) + (imag * imag)).squareRoot()
    }
    
    func conjugate() -> ComplexSample {
        return ComplexSample(real: real, imag: -imag)
    }
}

public extension [ComplexSample] {
    func magnitude() -> [Float] {
        return self.map { $0.magnitude() }
    }
    
    func conjugate() -> [ComplexSample] {
        return self.map { $0.conjugate() }
    }
}
