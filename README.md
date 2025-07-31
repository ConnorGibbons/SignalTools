# SignalTools

A high-performance Swift library for digital signal processing (DSP) operations, built on top of Apple's Accelerate framework.

## Features

### Filtering
- **IIR Filters**: Cascading biquad infinite impulse response filters with support for:
  - Low-pass filters
  - High-pass filters  
  - Custom filter parameters
- **FIR Filters**: Finite impulse response filters with:
  - Low-pass filter generation
  - Custom windowing functions (Hamming by default)
  - Zero-phase filtering with `filtfilt`
  - Support for both real and complex signals
- **Filter Protocol**: IIRFilter and FIRFilter conform to a shared protocol, Filter, allowing for abstraction.

### Demodulation
- **FM Demodulation**: Multiple implementations for frequency modulation demodulation:
  - Fast vectorized implementation using vDSP
  - Conceptual slow implementation for educational purposes

### Signal Processing Utilities
- **Frequency Shifting**: 
  - Standard precision (Float) frequency shifting to baseband --> If you're having issues with this, try high precision.
  - High-precision (Double) frequency shifting for artifact-free processing
- **Phase Operations**:
  - Phase calculation and unwrapping
  - Radians to frequency conversion
- **Sample/Time Conversion**: Utilities for converting between sample indices and time

### Array Extensions
- **Float Array Extensions**:
  - Statistical operations (mean, standard deviation)
  - Signal normalization
  - Optimized using vDSP functions
- **Complex Signal Extensions**:
  - Magnitude calculation for individual samples and arrays
  - Built on `DSPComplex` from Accelerate

## Requirements

- **Swift**: 5.1 or later
- **Platform**: macOS 10.15 or later
- **Dependencies**: Apple Accelerate framework

## Usage Examples

### Basic Filtering

```swift
import SignalTools

// Create an IIR low-pass filter
let filter = IIRFilter()
    .addLowpassFilter(sampleRate: 44100, frequency: 1000.0, q: 0.707)

// Filter your signal
var signal: [Float] = // your audio data
filter.filteredSignal(&signal)
```

### FM Demodulation

```swift
import SignalTools

// Demodulate FM signal
let complexSamples: [DSPComplex] = // your IQ data
let demodulated = demodulateFM(complexSamples)
```

### Frequency Shifting

```swift
import SignalTools

var rawIQ: [DSPComplex] = // your IQ samples
var result = [DSPComplex](repeating: DSPComplex(real: 0, imag: 0), count: rawIQ.count)

shiftFrequencyToBaseband(
    rawIQ: rawIQ,
    result: &result,
    frequency: 1000.0,  // Hz
    sampleRate: 48000   // Hz
)
```

### Signal Statistics

```swift
import SignalTools

let samples: [Float] = // your data
let mean = samples.average()
let stdDev = samples.standardDeviation()
let normalized = samples.normalize()
```

## Architecture

The library is organized into several key components:

- **Filter.swift**: IIR and FIR filter implementations
- **FM.swift**: FM demodulation algorithms  
- **Utils.swift**: Frequency shifting and phase utilities
- **Extensions.swift**: Convenience extensions for Float and DSPComplex arrays

## Plans
'vDSP.' is only available in macOS 10.15 and above. At some point I'd like to replace this with C (vDSP\_) functions to support older versions.
