//
//  BitBuffer.swift
//  SignalTools
//
//  Created by Connor Gibbons on 10/8/26.
//

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
    
    /// Extracts the value of the bits in this range of the BitBuffer.
    /// Any residual will be on the left-hand side.
    public subscript<T: FixedWidthInteger>(indexes: Range<Int>) -> T? {
        guard self.count >= indexes.upperBound && indexes.lowerBound >= 0 else { return nil }
        if indexes.count > T.bitWidth {
            print("ERROR: Attempted to extract more bits (\(indexes.count)) than the type can hold (\(T.bitWidth)).")
            return nil
        }
        var value: T = 0
        for index in indexes {
            value <<= 1
            value |= T(self[index])
        }
        return value
    }
    
    public subscript<T: FixedWidthInteger>(indexes: ClosedRange<Int>) -> T? {
        return self[indexes.lowerBound..<(indexes.upperBound+1)]
    }
    
    public subscript(indexes: Range<Int>) -> BitBuffer? {
        guard indexes.lowerBound >= 0, indexes.upperBound <= count else { return nil }
        var newBitBuffer = BitBuffer()
        for i in indexes {
            newBitBuffer.append(UInt8(self[i]))
        }
        return newBitBuffer
    }
    
    public subscript(indexes: ClosedRange<Int>) -> BitBuffer? {
        return self[indexes.lowerBound..<(indexes.upperBound+1)]
    }
    
    /// 'Padding' allows to prevent the appending of zero-fill bits, which are assumed to be on the left side.
    public mutating func append<T: FixedWidthInteger>(bits: T, padding: Int = 0) {
        var bits = bits << padding
        let mask: T = 1 << (T.bitWidth - 1)
        for _ in 0..<(bits.bitWidth - padding) {
            self.append((bits & mask) == 0 ? 0 : 1)
            bits = bits << 1
        }
    }
    
    public mutating func append(contentsOf: BitBuffer) {
        for i in 0..<contentsOf.count {
            self.append(UInt8(contentsOf[i]))
        }
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
    
    public func asIntArray() -> [Int] {
        var array: [Int] = []
        array.reserveCapacity(bitCount)
        for i in 0..<bitCount {
            array.append(self[i])
        }
        return array
    }
    
    /// Returns BitBuffer as a float array, each bit as an independent element.
    /// Useful for running correlations with bits as the signal / template.
    public func asFloatArray() -> [Float] {
        var array: [Float] = []
        array.reserveCapacity(bitCount)
        for i in 0..<bitCount {
            array.append(Float(2 * self[i] - 1))
        }
        return array
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
