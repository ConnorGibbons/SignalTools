//
//  DSPTypes.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 1/14/26.
//

import Foundation

#if canImport(Accelerate)
import Accelerate
public typealias ComplexSignal = DSPComplex
public typealias SplitComplexSignal = DSPSplitComplex
#else
struct ComplexSignal: Equatable {
    var real: Float
    var imag: Float
}

struct SplitComplexSignal {
    var real: UnsafeMutablePointer<Float>
    var imag: UnsafeMutablePointer<Float>
}
#endif

public extension ComplexSignal {
    func magnitude() -> Float {
        return ((real * real) + (imag * imag)).squareRoot()
    }
}

public extension [ComplexSignal] {
    func magnitude() -> [Float] {
        return self.map({$0.magnitude()})
    }
}
