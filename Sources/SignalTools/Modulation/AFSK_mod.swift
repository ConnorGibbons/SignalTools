//
//  AFSK_mod.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 8/25/25.
//
//  Tools for creating AFSK-modulated bitstreams.

import Foundation

/// Creates an AFSK modulated bitstream.
/// markFreq encodes a 1, spaceFreq encodes a 0.
/// Output would need to be modulated onto a carrier in order to be transmitted.
/// Phase is continuous. 
public func afskModulate(bits: BitBuffer, baud: Int, sampleRate: Int, markFreq: Int, spaceFreq: Int) -> [Float]? {
    guard sampleRate % baud == 0 else { print("sampleRate must be integer multiple of baud."); return nil }
    guard markFreq < (sampleRate / 2) && spaceFreq < (sampleRate / 2) else { print("mark/space freqs must be below nyquist (sampleRate / 2)."); return nil }
    
    let samplesPerBit = sampleRate / baud
    var samples: [Float] = []
    samples.reserveCapacity(bits.count * samplesPerBit)
    var currPhase: Float = 0
    for currBitIndex in 0..<bits.count {
        genAFSKBitSamples(samplesPerBit: samplesPerBit, sampleRate: sampleRate, freq: bits[currBitIndex] == 1 ? markFreq : spaceFreq, phase: &currPhase, samples: &samples)
    }
    return samples
}

private func genAFSKBitSamples(samplesPerBit: Int, sampleRate: Int, freq: Int, phase: inout Float, samples: inout [Float]) {
    // sampleRate / freq = samples per cycle (spc), 1/spc = cycles per sample x 2pi rad per cycle = 2pi/spc rad per sample
    // This is just that formula but rearranged.
    let perSamplePhaseDiff = 2 * Float.pi * Float(freq) / Float(sampleRate)
    for _ in 0..<samplesPerBit {
        samples.append(cos(phase))
        phase += perSamplePhaseDiff
        if(phase > (2 * Float.pi)) { phase = phase - (2 * Float.pi) }
    }
}


