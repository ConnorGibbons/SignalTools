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
public struct ComplexSample: Equatable {
    public var real: Float
    public var imag: Float
    public init(real: Float, imag: Float) {
        self.real = real
        self.imag = imag
    }
}

public struct SplitComplexSamples {
    public var realp: UnsafeMutablePointer<Float>
    public var imagp: UnsafeMutablePointer<Float>
    public init(realp: UnsafeMutablePointer<Float>, imagp: UnsafeMutablePointer<Float>) {
        self.realp = realp
        self.imagp = imagp
    }
}

public struct DoubleComplexSample: Equatable {
    public var real: Double
    public var imag: Double
    public init(real: Double, imag: Double) {
        self.real = real
        self.imag = imag
    }
}

public struct SplitDoubleComplexSamples {
    public var realp: UnsafeMutablePointer<Double>
    public var imagp: UnsafeMutablePointer<Double>
    public init(realp: UnsafeMutablePointer<Double>, imagp: UnsafeMutablePointer<Double>) {
        self.realp = realp
        self.imagp = imagp
    }
}

public enum WindowFunction {
    case hanningNormalized
    case hanningDenormalized
    case hamming
    case blackman
}

public protocol FloatingPointGeneratable: BinaryFloatingPoint {}

public protocol FloatingPointBiquadFilterable: BinaryFloatingPoint {}

extension Float: FloatingPointGeneratable {}
extension Double: FloatingPointGeneratable {}
extension Float: FloatingPointBiquadFilterable {}
extension Double: FloatingPointBiquadFilterable {}
#endif

public protocol BiquadFilter<T> {
    associatedtype T: FloatingPointBiquadFilterable
    init?(coefficients: [Double], channelCount: Int, sectionCount: Int, ofType: T.Type)
    mutating func apply(input: [T]) -> [T]
    mutating func apply(input: [T], output: inout [T])
}

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
