//
//  Extensions.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 6/24/25.
//
import Foundation

public extension [Float] {
    
    func standardDeviation() -> Float {
        var result = Float()
        var mean = Float()
        var disregardableOutput: [Float] = .init(repeating: 0.0, count: self.count)
        DSP.normalize(input: self, inputStride: 1, output: &disregardableOutput, outputStride: 1, calculatedMean: &mean, calculatedStdDev: &result, count: self.count)
        return result
    }
    
    func average() -> Float {
        var result = Float()
        DSP.mean(input: self, inputStride: 1, output: &result, count: self.count)
        return result
    }
    
    func normalize() -> [Float] {
        var result = [Float].init(repeating: 0.0, count: self.count)
        var mean: Float = 0.0
        var standardDeviation: Float = 0.0
        DSP.normalize(input: self, inputStride: 1, output: &result, outputStride: 1, calculatedMean: &mean, calculatedStdDev: &standardDeviation, count: self.count)
        return result
    }
    
    func topKIndices(_ k: Int) -> [Int] {
        guard k <= self.count else {
            return topKIndices(self.count)
        }
        
        var result: [Int] = .init(repeating: 0, count: k)
        var mutableSelf = self
        for i in 0..<k {
            let topIndex = Int(DSP.indexOfMaximum(input: mutableSelf).0)
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
            let topIndexAndValue = DSP.indexOfMaximum(input: mutableSelf)
            result[i] = (Int(topIndexAndValue.0), topIndexAndValue.1)
            mutableSelf[Int(topIndexAndValue.0)] = -Float.infinity
        }
        return result
    }
    
}
