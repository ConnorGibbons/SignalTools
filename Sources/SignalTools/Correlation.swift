//
//  Correlation.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 8/27/25.
//

import Accelerate

/// Takes in a signal &  a template to correlate, returns correlation values at each lag (offset from start)
/// This is a convenience wrapper around vDSP\_conv
public func slidingCorrelation(signal: [Float], template: [Float]) -> [Float]? {
    guard signal.isEmpty == false, template.isEmpty == false, signal.count >= template.count else {
        return nil
    }
    let outputCount = signal.count - template.count + 1
    var result: [Float] = .init(repeating: 0, count: outputCount)
    signal.withUnsafeBufferPointer { signalPtr in
        template.withUnsafeBufferPointer { templatePtr in
            let signalBasePointer = signalPtr.baseAddress!
            let templateBasePointer = templatePtr.baseAddress!
            vDSP_conv(signalBasePointer, vDSP_Stride(1), templateBasePointer, vDSP_Stride(1), &result, vDSP_Stride(1), vDSP_Length(outputCount), vDSP_Length(template.count))
        }
    }
    return result
}
