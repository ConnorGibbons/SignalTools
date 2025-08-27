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

public struct BitBuffer {
    // Buffers filled left to right
    private var buffer: [ByteBuffer] = []
    private var bitCount: Int = 0
    public var count: Int { return bitCount }
    
    public init() {}
    
    public mutating func append(_ bit: UInt8) {
        guard bit == 0 || bit == 1 else { print("Cannot append bit to BitBuffer, it must be 0 or 1."); return }
        var index = buffer.count - 1
        if buffer.isEmpty || buffer[index].isFull {
            buffer.append(ByteBuffer())
            index += 1
        }
        buffer[index].append(bit)
        bitCount += 1
    }
    
    public subscript (index: Int) -> Int {
        let byteIndex = index >> 3 // Equivalent to division by 8 w/ rounding down
        let bitIndex = index & 7
        guard byteIndex < buffer.count else { return 0 }
        return buffer[byteIndex][bitIndex]
    }
    
    public func getBitstring() -> String {
        var bitString: String = String()
        bitString.reserveCapacity(bitCount)
        for i in 0..<bitCount {
            if(self[i] == 0) { bitString += "0" }
            else { bitString += "1" }
        }
        return bitString
    }
    
}

private struct ByteBuffer: Equatable {
    private var buffer: UInt8 = 0
    private var bitCount: Int = 0
    var isFull: Bool { bitCount == 8 }
    
    mutating func append(_ bit: UInt8) {
        guard bit == 0 || bit == 1 else { print("Cannot append bit to ByteBuffer, must be 0 or 1"); return }
        guard !isFull else { print("Cannot append bit to ByteBuffer, it is full."); return }
        if bit == 1 {
            let mask = UInt8(0b10000000) >> bitCount
            buffer |= mask
        }
        bitCount += 1
    }
    
    static func == (lhs: ByteBuffer, rhs: ByteBuffer) -> Bool {
        return lhs.buffer == rhs.buffer
    }
    
    subscript(index: Int) -> Int {
        let mask: UInt8 = 0b10000000 >> index
        return (buffer & mask) != 0 ? 1 : 0
    }
    
    mutating func clear() {
        buffer = 0
        bitCount = 0
    }
    
}

/// General-purpose Binary AFSK demodulator, taking mark (1) and space (0) frequencies, sample rate, baud as parameters.
/// Works on Binary *AFSK*, where bit values are encoded as tones. Note that this will not work with FSK -- where FM demod output will (ideally) alternate between two amplitude levels as opposed to AFSK's tones.
/// Outputs: BitBuffer (see struct) and a [Float] contianing the confidence with which each bit was chosen. 'confidence' refers to the difference in Goertzel power.
public func afskDemodulate(samples: [Float], sampleRate: Int, baud: Int, markFreq: Int, spaceFreq: Int) -> (BitBuffer, [Float])? {
    let nyquistFreq: Float = Float(sampleRate) / 2.0
    guard Float(markFreq) < nyquistFreq && Float(spaceFreq) < nyquistFreq else {
        print("Error: mark & space frequencies are not representable within this sample rate.")
        return nil
    }
    guard sampleRate % baud == 0 else {
        print("Error: sampleRate must be an integer multiple of baud.")
        return nil
    }
    let samplesPerBit = sampleRate / baud
    var bits: BitBuffer = BitBuffer()
    var confidenceArr: [Float] = []
    var currIndex = 0
    let markCoeff = getGoertzelCoeff(targetFrequency: Float(markFreq), sampleRate: sampleRate)
    let spaceCoeff = getGoertzelCoeff(targetFrequency: Float(spaceFreq), sampleRate: sampleRate)
    while(currIndex + samplesPerBit <= samples.count) {
        let bitSamples = Array(samples[currIndex..<(currIndex+samplesPerBit)])
        let markPower = goertzelPower(samples: bitSamples, coeff: markCoeff, sampleRate: sampleRate)
        let spacePower = goertzelPower(samples: bitSamples, coeff: spaceCoeff, sampleRate: sampleRate)
        markPower > spacePower ? bits.append(1) : bits.append(0)
        confidenceArr.append(abs(markPower - spacePower))
        currIndex += samplesPerBit
    }
    return (bits, confidenceArr)
}

/// General-purpose Binary AFSK demodulator, taking mark (1) and space (0) frequencies, sample rate, baud as parameters.
/// Works on Binary *AFSK*, where bit values are encoded as tones. Note that this will not work with FSK -- where FM demod output will (ideally) alternate between two amplitude levels as opposed to AFSK's tones.
/// This version takes in mark & space frequencies instead as computed coefficients (see 'coeff' in goertzelPower) to avoid recomputing when calling this function multiple times.
/// Outputs: BitBuffer (see struct) and a [Float] contianing the confidence with which each bit was chosen. 'confidence' refers to the difference in Goertzel power.
public func afskDemodulate(samples: [Float], sampleRate: Int, baud: Int, markCoeff: Float, spaceCoeff: Float) -> (BitBuffer, [Float])? {
    let nyquistFreq: Float = Float(sampleRate) / 2.0
    guard sampleRate % baud == 0 else {
        print("Error: sampleRate must be an integer multiple of baud.")
        return nil
    }
    let samplesPerBit = sampleRate / baud
    var bits: BitBuffer = BitBuffer()
    var confidenceArr: [Float] = []
    var currIndex = 0
    while(currIndex + samplesPerBit <= samples.count) {
        let bitSamples = Array(samples[currIndex..<(currIndex+samplesPerBit)])
        let markPower = goertzelPower(samples: bitSamples, coeff: markCoeff, sampleRate: sampleRate)
        let spacePower = goertzelPower(samples: bitSamples, coeff: spaceCoeff, sampleRate: sampleRate)
        markPower > spacePower ? bits.append(1) : bits.append(0)
        confidenceArr.append(abs(markPower - spacePower))
        currIndex += samplesPerBit
    }
    return (bits, confidenceArr)
}

/// Computes power at targetFrequency throughout samples.
/// Equivalent to a single-bin DFT, good for efficient tone detection.
/// Based on pseudocode here: https://en.wikipedia.org/wiki/Goertzel_algorithm
public func goertzelPower(samples: [Float], targetFrequency: Float, sampleRate: Int) -> Float {
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

public func goertzelPower(samples: [Float], coeff: Float, sampleRate: Int) -> Float {
    var sPrev: Float = 0.0
    var sPrev2: Float = 0.0
    for n in 0..<samples.count {
        let sCurr = samples[n] + coeff * sPrev - sPrev2
        sPrev2 = sPrev
        sPrev = sCurr
    }
    return (sPrev * sPrev) + (sPrev2 * sPrev2) - (coeff * sPrev * sPrev2)
}

public func getGoertzelCoeff(targetFrequency: Float, sampleRate: Int) -> Float {
    let omega = (2.0 * Float.pi) * (targetFrequency / Float(sampleRate))
    return 2 * cos(omega)
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
