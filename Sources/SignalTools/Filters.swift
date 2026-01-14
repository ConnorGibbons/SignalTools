//
//  Filters.swift
//  RTLSDRTesting
//
//  Created by Connor Gibbons  on 4/24/25.
//

// -------------------------------------------------------------------------------------------------------------
//       Example filters, really just here for conceptual understanding. I don't recommend using them
// -------------------------------------------------------------------------------------------------------------

// This tries to remove a 0Hz component from a signal.
// Takes current sample, subtracts previous sample, adds result of alpha * previous output.
// Ex.
// Signal: 1,1,1,1,1,1 --> 0Hz
// Output: (1 - 0) + (.995 * 0) = 1; (1 - 1) + (.995 * 1) = .995; (1 - 1) + (.995 * .995) = .995^2
// First term will always be 0, second will eventually converge to 0.
public func removeDC(samples: [Float], alpha: Float = 0.995) -> [Float]? {
    guard samples.count > 0 && alpha >= 0 && alpha <= 1 else {
        print("Error with removeDC parameters!")
        return nil
    }
    
    var y = [Float].init(repeating: 0.0, count: samples.count)
    var prevRaw: Float = 0
    var prevOutput: Float = 0
    for i in 0..<samples.count {
        let curr = samples[i] - prevRaw + (alpha * prevOutput)
        prevRaw = samples[i]
        prevOutput = curr
        y[i] = curr
    }
    return y
}

public func lowPass(samples: [Float], alpha: Float = 0.05) -> [Float] {
    var y = [Float](repeating: 0, count: samples.count)
    y[0] = samples[0]
    for i in 1..<samples.count {
        y[i] = alpha * samples[i] + (1 - alpha) * y[i - 1]
    }
    return y
}

public func normalize(samples: [Float], peak: Float = 2.3561945) -> [Float] {
    return samples.map { min(max($0 / peak, -1.0), 1.0) }
}

// This downsamples by only picking 1 for every 42 samples. It will cause aliasing!
public func decimate(samples: [Float]) -> [Float] {
    var result: [Float] = []
    for i in stride(from: 0, to: samples.count, by: 42) {
        result.append(samples[i])
    }
    return result
}
