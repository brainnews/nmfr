import AVFoundation
import MediaToolbox
import Accelerate

/// Installs an MTAudioProcessingTap on an AVPlayerItem and extracts per-block
/// peak amplitude (time-domain) for the visualiser.
final class AudioTapProcessor {

    private(set) var tap: MTAudioProcessingTap?

    private let outputBins   = 64
    private let waveformBins = 128

    // Pre-allocated — never allocated inside the audio callback
    private var workBuffer      = [Float](repeating: 0, count: 65536)
    private var bins            = [Float](repeating: 0, count: 64)
    private var smoothed        = [Float](repeating: 0, count: 64)
    private var waveSmoothed    = [Float](repeating: 0, count: 128)

    /// Latest peak amplitudes — used for signal-presence detection.
    var latestMagnitudes = [Float](repeating: 0, count: 64)

    /// Latest signed oscilloscope samples (128 points, –1…+1).
    /// Written by audio thread, polled by main-thread timer.
    var latestWaveform = [Float](repeating: 0, count: 128)

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
            prepare: nil,
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

    // MARK: - Waveform extraction (real-time audio thread)

    fileprivate func processBuffer(_ abl: UnsafeMutablePointer<AudioBufferList>, frameCount: CMItemCount) {
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
            // Write directly to shared array — no dispatch, no allocation
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

private let atpProcess: MTAudioProcessingTapProcessCallback = {
    tap, numberFrames, _, bufferListInOut, numberFramesOut, flagsOut in
    MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut)
    let processor = Unmanaged<AudioTapProcessor>
        .fromOpaque(MTAudioProcessingTapGetStorage(tap))
        .takeUnretainedValue()
    processor.processBuffer(bufferListInOut, frameCount: numberFrames)
}
