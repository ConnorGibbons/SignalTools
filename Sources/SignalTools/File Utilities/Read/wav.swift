//
//  wav.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 11/5/25.
//
//  Functions for reading data from .wav files.

import Foundation

/// Read IQ Samples from a .wav where samples are stored as 16-bit integers.
/// Samples are expected to be interleaved IQ.
/// Samples are adjusted to be in range [-1,1]
public func readIQFromWAV16Bit(fileURL: URL) throws -> [DSPComplex] {
    let data = try Data(contentsOf: fileURL)
    
    var iqOutput: [DSPComplex] = []
    
    let iqData = data.dropFirst(44)
    guard iqData.count % 4 == 0 else {
        print("IQ Data is not properly formatted.")
        return []
    }
    
    iqData.withUnsafeBytes { (iqDataPtr: UnsafeRawBufferPointer) in
        let int16ArrayBasePointer = iqDataPtr.bindMemory(to: Int16.self)
        var currOffset: Int = 0
        while currOffset < int16ArrayBasePointer.count {
            let realSample = Float(int16ArrayBasePointer[currOffset]) / 32768.0
            let imagSample = Float(int16ArrayBasePointer[currOffset + 1]) / 32768.0
            iqOutput.append(DSPComplex(real: realSample, imag: imagSample))
            currOffset += 2
        }
    }
    
    return iqOutput
}
public func readIQFromWAV16Bit(filePath: String) throws -> [DSPComplex] {
    let fileURL = URL(fileURLWithPath: filePath)
    return try readIQFromWAV16Bit(fileURL: fileURL)
}

/// Reads samples from .wav where samples are stored as 16-bit integers.
/// Samples are adjusted to be floats in range [-1,1]
public func readAudioFromWAV16Bit(filePath: String) throws -> [Float] {
    let fileURL = URL(fileURLWithPath: filePath)
    let data = try Data(contentsOf: fileURL)
    var audioOutput: [Float] = []
    data.dropFirst(44).withUnsafeBytes { (audioDataPtr: UnsafeRawBufferPointer) in      // First 44 bytes are .wav metadata
        let int16ArrayBasePointer = audioDataPtr.bindMemory(to: Int16.self)
        var currOffset: Int = 0
        while currOffset < int16ArrayBasePointer.count {
            audioOutput.append(Float(int16ArrayBasePointer[currOffset]) / 32768.0)      // Map from Int16 (.wav sample) to Float in range [-1.0, 1.0]
            currOffset += 1
        }
    }
    return audioOutput
}
