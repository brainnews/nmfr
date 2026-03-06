import AVFoundation
import MediaToolbox
import Accelerate

/// Installs an MTAudioProcessingTap on an AVPlayerItem.
/// Applies a 5-band peaking EQ in-place, then extracts waveform and
/// magnitude data for the visualiser.
final class AudioTapProcessor {

    private(set) var tap: MTAudioProcessingTap?

    private let outputBins   = 64
    private let waveformBins = 128

    // Pre-allocated — never allocated inside the audio callback
    private var workBuffer   = [Float](repeating: 0, count: 65536)
    private var bins         = [Float](repeating: 0, count: 64)
    private var smoothed     = [Float](repeating: 0, count: 64)
    private var waveSmoothed = [Float](repeating: 0, count: 128)

    /// Latest peak amplitudes — used for signal-presence detection.
    var latestMagnitudes = [Float](repeating: 0, count: 64)

    /// Latest signed oscilloscope samples (128 points, –1…+1).
    /// Written by audio thread, polled by main-thread timer.
    var latestWaveform = [Float](repeating: 0, count: 128)

    // MARK: - EQ parameters
    // Written from the main thread, read on the audio thread.
    // Benign data race — intentional, safe on ARM64 (same pattern as latestWaveform).

    static let eqBandCount = 5
    private static let eqMaxChannels = 8
    private static let eqFrequencies: [Float] = [60, 250, 1000, 4000, 12000]
    private static let eqQ: Float = 1.41

    var eqEnabled: Bool  = false
    var eqGains: [Float] = [Float](repeating: 0, count: 5)   // dB, one per band
    var eqDirty: Bool    = true                               // recompute coefficients

    // Audio-thread-only EQ state (never touched from main thread)
    private var sampleRate: Float = 44100.0
    // Normalised biquad coefficients: [b0, b1, b2, a1, a2] * bandCount (flattened)
    private var eqCoeffs = [Float](repeating: 0, count: 5 * 5)
    // Transposed direct-form-II delay lines: indexed [band * maxChannels + channel]
    private var eqW1 = [Float](repeating: 0, count: 5 * 8)
    private var eqW2 = [Float](repeating: 0, count: 5 * 8)

    init() {
        createTap()
    }

    // MARK: - Tap creation

    private func createTap() {
        let selfPtr = Unmanaged.passRetained(self).toOpaque()
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: selfPtr,
            `init`: atpInit,
            finalize: atpFinalize,
            prepare: atpPrepare,
            unprepare: nil,
            process: atpProcess
        )
        var out: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &out
        )
        if status == noErr {
            tap = out
        } else {
            Unmanaged<AudioTapProcessor>.fromOpaque(selfPtr).release()
        }
    }

    // MARK: - Sample rate (called from prepare callback on the audio thread)

    fileprivate func setSampleRate(_ rate: Float) {
        guard rate > 0, rate != sampleRate else { return }
        sampleRate = rate
        eqDirty = true
    }

    // MARK: - EQ coefficient computation (audio thread only)

    private func recomputeCoefficients() {
        for band in 0..<AudioTapProcessor.eqBandCount {
            let gain  = eqGains[band]
            let f0    = AudioTapProcessor.eqFrequencies[band]
            let q     = AudioTapProcessor.eqQ
            let fs    = sampleRate

            let A     = powf(10.0, gain / 40.0)
            let w0    = 2.0 * Float.pi * f0 / fs
            let sinW  = sinf(w0)
            let cosW  = cosf(w0)
            let alpha = sinW / (2.0 * q)
            let a0    = 1.0 + alpha / A

            let base  = band * 5
            eqCoeffs[base + 0] = (1.0 + alpha * A) / a0   // b0
            eqCoeffs[base + 1] = (-2.0 * cosW)     / a0   // b1
            eqCoeffs[base + 2] = (1.0 - alpha * A) / a0   // b2
            eqCoeffs[base + 3] = (-2.0 * cosW)     / a0   // a1 (same as b1 / a0)
            eqCoeffs[base + 4] = (1.0 - alpha / A) / a0   // a2
        }
        eqDirty = false
    }

    // MARK: - In-place EQ application (audio thread)

    private func applyEQToBufferList(_ abl: UnsafeMutablePointer<AudioBufferList>) {
        let numBuffers = Int(abl.pointee.mNumberBuffers)
        withUnsafeMutablePointer(to: &abl.pointee.mBuffers) { buffersPtr in
            for bufIdx in 0..<numBuffers {
                let buf = buffersPtr.advanced(by: bufIdx).pointee
                guard let data = buf.mData, buf.mDataByteSize > 0 else { continue }
                let numCh  = Int(buf.mNumberChannels)
                let count  = Int(buf.mDataByteSize) / MemoryLayout<Float>.size
                let ptr    = data.bindMemory(to: Float.self, capacity: count)

                for i in 0..<count {
                    // Determine channel index for filter-state tracking.
                    // Interleaved (numCh > 1): channels interleave within one buffer.
                    // Non-interleaved (numCh == 1): each buffer is a separate channel.
                    let ch = numCh > 1
                        ? (i % numCh)
                        : min(bufIdx, AudioTapProcessor.eqMaxChannels - 1)

                    var x = ptr[i]
                    for band in 0..<AudioTapProcessor.eqBandCount {
                        let base = band * 5
                        let b0   = eqCoeffs[base + 0]
                        let b1   = eqCoeffs[base + 1]
                        let b2   = eqCoeffs[base + 2]
                        let a1   = eqCoeffs[base + 3]
                        let a2   = eqCoeffs[base + 4]
                        let si   = band * AudioTapProcessor.eqMaxChannels + ch
                        let w1   = eqW1[si]
                        let w2   = eqW2[si]
                        // Transposed direct form II
                        let y    = b0 * x + w1
                        eqW1[si] = b1 * x - a1 * y + w2
                        eqW2[si] = b2 * x - a2 * y
                        x = y
                    }
                    ptr[i] = x
                }
            }
        }
    }

    // MARK: - Main buffer processing (audio thread)

    fileprivate func processBuffer(_ abl: UnsafeMutablePointer<AudioBufferList>, frameCount: CMItemCount) {
        // Apply EQ first — visualiser then reflects the EQ'd signal.
        if eqEnabled {
            if eqDirty { recomputeCoefficients() }
            applyEQToBufferList(abl)
        }

        let buffer = abl.pointee.mBuffers
        guard let data = buffer.mData, buffer.mDataByteSize > 0 else { return }

        let sampleCount = min(
            Int(buffer.mDataByteSize) / MemoryLayout<Float>.size,
            workBuffer.count
        )
        guard sampleCount > 0 else { return }

        let floatPtr = data.bindMemory(to: Float.self, capacity: sampleCount)

        // Downsample signed samples for the oscilloscope waveform (no abs — keeps sign)
        let waveStride = max(1, sampleCount / waveformBins)
        for i in 0..<waveformBins {
            let idx = min(i * waveStride, sampleCount - 1)
            let sample = floatPtr[idx]
            waveSmoothed[i] = 0.4 * sample + 0.6 * waveSmoothed[i]
            latestWaveform[i] = waveSmoothed[i]
        }

        // Absolute values into pre-allocated workBuffer — no heap allocation
        vDSP_vabs(floatPtr, 1, &workBuffer, 1, vDSP_Length(sampleCount))

        // Peak per bin using pre-allocated bins array
        let samplesPerBin = max(1, sampleCount / outputBins)
        workBuffer.withUnsafeBufferPointer { ptr in
            for i in 0..<outputBins {
                let start = i * samplesPerBin
                let end   = min(start + samplesPerBin, sampleCount)
                guard start < end else { break }
                var peak: Float = 0
                vDSP_maxv(ptr.baseAddress! + start, 1, &peak, vDSP_Length(end - start))
                bins[i] = peak
            }
        }

        // Clamp to 0–1
        var lo: Float = 0, hi: Float = 1
        vDSP_vclip(bins, 1, &lo, &hi, &bins, 1, vDSP_Length(outputBins))

        // Exponential smoothing: fast attack, slow decay
        for i in 0..<outputBins {
            smoothed[i] = bins[i] > smoothed[i]
                ? 0.5  * bins[i] + 0.5  * smoothed[i]
                : 0.15 * bins[i] + 0.85 * smoothed[i]
            latestMagnitudes[i] = smoothed[i]
        }
    }
}

// MARK: - C callbacks (file-scope, no captures)

private let atpInit: MTAudioProcessingTapInitCallback = { _, clientInfo, tapStorageOut in
    tapStorageOut.pointee = clientInfo
}

private let atpFinalize: MTAudioProcessingTapFinalizeCallback = { tap in
    Unmanaged<AudioTapProcessor>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
}

private let atpPrepare: MTAudioProcessingTapPrepareCallback = { tap, _, processingFormat in
    let processor = Unmanaged<AudioTapProcessor>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap))
        .takeUnretainedValue()
    processor.setSampleRate(Float(processingFormat.pointee.mSampleRate))
}

private let atpProcess: MTAudioProcessingTapProcessCallback = {
    tap, numberFrames, _, bufferListInOut, numberFramesOut, flagsOut in
    MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut)
    let processor = Unmanaged<AudioTapProcessor>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap))
        .takeUnretainedValue()
    processor.processBuffer(bufferListInOut, frameCount: numberFrames)
}
