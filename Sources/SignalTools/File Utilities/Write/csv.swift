//
//  csv.swift
//  SignalTools
//
//  Created by Connor Gibbons  on 11/13/25.
//
import Foundation
import Accelerate

func directoryExists(_ path: String) -> Bool {
    var isDirObjCBool: ObjCBool = true
    if FileManager.default.fileExists(atPath: path, isDirectory: &isDirObjCBool) {
        return isDirObjCBool.boolValue
    } else {
        return false
    }
}

/// Writes the provided audi (Float) samples to a .csv.
/// Each line is as follows: amplitude\n
public func writeAudioToTempFile(_ audio: [Float], prefix: String = "") {
    let dir = "/tmp/audio/"
    let path = "\(dir)\(prefix)\(Date().timeIntervalSince1970).csv"

    if(!directoryExists(dir)) {
        do {
            try FileManager().createDirectory(atPath: dir, withIntermediateDirectories: false)
        }
        catch {
            print("\(dir) does not exist, and the attempt to create it failed.")
            return
        }
    }
    
    writeAudioToFile(audio, path: path)
}

/// Writes the provided audi (Float) samples to a .csv.
/// Each line is as follows: amplitude\n
public func writeAudioToFile(_ audio: [Float], path: String = "") {
    var csvText = "Amplitude\n"
    for sample in audio {
        csvText.append("\(sample)\n")
    }
    do {
        try csvText.write(toFile: path, atomically: true, encoding: .utf8)
    }
    catch {
        print("Failed to write audio data to csv file.")
    }
}

/// Write samples to specified path in .csv format.
/// Each line is as follows: I,Q\n
public func samplesToCSV(_ samples: [DSPComplex], path: String) {
    var csvText = "I,Q\n"
    for sample in samples {
        csvText.append("\(sample.real),\(sample.imag)\n")
    }
    do {
        try csvText.write(toFile: path, atomically: true, encoding: .utf8)
    }
    catch {
        print("Failed to write sample data to csv file.")
    }
}
