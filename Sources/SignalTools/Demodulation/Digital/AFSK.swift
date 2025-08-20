//
//  AFSK.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 8/20/25.
//
//  Demodulator for Binary AFSK (Audio Frequency Shift Keying) signals.
//  Differs from typical FSK in that bits are encoded as tones rather than fixed frequencies.
//  AFSK modulated signals, after FM demodulation, will look like audio waveforms.

import Foundation
import Accelerate

/// Computes power at targetFrequency throughout samples.
/// Equivalent to a single-bin DFT, good for efficient tone detection.
/// Based on pseudocode here: https://en.wikipedia.org/wiki/Goertzel_algorithm
public func goertzelPower(samples: [Float], targetFrequency: Float, sampleRate: Int) -> Float {
    let bin = calcBinIndex(targetFrequency: targetFrequency, sampleCount: samples.count, sampleRate: sampleRate)
    let omega = (2.0 * Float.pi) * (targetFrequency / Float(sampleRate))
    let coeff: Float = 2 * cos(omega)
    var sPrev: Float = 0.0
    var sPrev2: Float = 0.0
    for n in 0..<samples.count {
        let sCurr = samples[n] + coeff * sPrev - sPrev2
        sPrev2 = sPrev
        sPrev = sCurr
    }
    return (sPrev * sPrev) + (sPrev2 * sPrev2) - (coeff * sPrev * sPrev2)
}

/// Returns the frequency corresponding to a DFT bin at binNum.
/// Bin X = X cycles over N samples = (X/N) cycles per sample
/// Ex. bin 1 when 'samples' is 1024 is (1/1024) cycles per sample
/// If sample rate is 'Z', we have (1/1024)xZ Hz
/// Z = 48,000 Hz, gives us (1/1024)cycles per sample x 48000 samples/sec = 46.875 cycles/sec (Hz)
/// This gives us: Bin X = (X/N)xZ Hz
func calcBinFreq(binNum: Int, sampleCount: Int, sampleRate: Int) -> Float {
    return (Float(binNum)/Float(sampleCount))*Float(sampleRate)
}

/// Returns the index of the DFT bin most closely corresponding to the target frequency.
/// We can take the difference in frequency when advancing to the next bin to be equivalent to the frequency of the first bin.
/// A.K.A, (1/sampleCount) x sampleRate = sampleRate/sampleCount
/// Bin corresponding to freq. we want would then be dividing targetFrequency by freqDiffPerBin.
func calcBinIndex(targetFrequency: Float, sampleCount: Int, sampleRate: Int) -> Int {
    let freqDiffPerBin = Float(sampleRate)/Float(sampleCount)
    return Int((targetFrequency/freqDiffPerBin).rounded(.toNearestOrEven))
}
