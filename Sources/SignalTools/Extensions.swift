//
//  Extensions.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 6/24/25.
//

import Accelerate

public extension [Float] {
    
    func standardDeviation() -> Float {
        var result = Float()
        var mean = Float()
        let stride = vDSP_Stride(1)
        vDSP_normalize(self, stride, nil, vDSP_Stride(1), &mean, &result, vDSP_Length(self.count))
        return result
    }
    
    func average() -> Float {
        var result = Float()
        let stride = vDSP_Stride(1)
        vDSP_meanv(self, stride, &result, vDSP_Length(self.count))
        return result
    }
    
    func normalize() -> [Float] {
        let stride = vDSP_Stride(1)
        var result = [Float].init(repeating: 0.0, count: self.count)
        var mean: Float = 0.0
        var standardDeviation: Float = 0.0
        vDSP_normalize(self, stride, &result, stride, &mean, &standardDeviation, vDSP_Length(self.count))
        return result
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
