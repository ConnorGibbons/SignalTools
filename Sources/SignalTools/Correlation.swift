//
//  Correlation.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 8/27/25.
//

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
            DSP.convolve(signal: signalBasePointer, signalStride: 1, kernel: templateBasePointer, kernelStride: 1, result: &result, resultStride: 1, outputLength: outputCount, kernelLength: template.count)
        }
    }
    return result
}
