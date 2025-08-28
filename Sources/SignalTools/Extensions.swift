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
    
    func topKIndices(_ k: Int) -> [Int] {
        guard k <= self.count else {
            return topKIndices(self.count)
        }
        
        var result: [Int] = .init(repeating: 0, count: k)
        var mutableSelf = self
        for i in 0..<k {
            let topIndex = Int(vDSP.indexOfMaximum(mutableSelf).0)
            result[i] = topIndex
            mutableSelf[topIndex] = -Float.infinity
        }
        return result
    }
    
    func topKIndicesWithValues(_ k: Int) -> [(Int, Float)] {
        guard k <= self.count else {
            return topKIndicesWithValues(self.count)
        }
        
        var result: [(Int, Float)] = .init(repeating: (0, 0), count: k)
        var mutableSelf = self
        for i in 0..<k {
            let topIndexAndValue = vDSP.indexOfMaximum(mutableSelf)
            result[i] = (Int(topIndexAndValue.0), topIndexAndValue.1)
            mutableSelf[Int(topIndexAndValue.0)] = -Float.infinity
        }
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
