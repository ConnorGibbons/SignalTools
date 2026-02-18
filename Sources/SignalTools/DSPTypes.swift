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
#else
struct ComplexSignal: Equatable {
    var real: Float
    var imag: Float
}

struct SplitComplexSignal {
    var realp: UnsafeMutablePointer<Float>
    var imagp: UnsafeMutablePointer<Float>
}
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
