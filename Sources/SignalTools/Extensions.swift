//
//  Extensions.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 6/24/25.
//

import Accelerate

extension [Float] {
    
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

extension DSPComplex {
    
    func magnitude() -> Float {
        return ((real * real) + (imag * imag)).squareRoot()
    }
    
}

extension [DSPComplex] {
    
    func magnitude() -> [Float] {
        return self.map({$0.magnitude()})
    }
    
}
