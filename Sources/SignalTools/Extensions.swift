//
//  Extensions.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 6/24/25.
//

import Accelerate

public extension [Float] {
    
    func standardDeviation() -> Float {
        return vDSP.standardDeviation(self)
    }
    
    func average() -> Float {
        return vDSP.mean(self)
    }
    
    func normalize() -> [Float] {
        return vDSP.normalize(self)
    }
    
}

public extension DSPComplex {
    
    func magnitude() -> Float {
        return ((real * real) + (imag * imag)).squareRoot()
    }
    
}

public extension [DSPComplex] {
    
    func magnitude() -> [Float] {
        return self.map({$0.magnitude()})
    }
    
}
