import ShazamKit
import AVFoundation

/// Wraps SHSession to match live radio audio against Shazam's catalog.
/// All published properties update on the main actor.
@MainActor
final class ShazamService: NSObject, ObservableObject {
    /// The most recent successful match, or nil when unmatched / stopped.
    @Published var match: SHMediaItem? = nil
    @Published var isMatching: Bool = false

    private let session = SHSession()

    override init() {
        super.init()
        session.delegate = self
    }

    /// Submit a block of accumulated PCM samples for identification.
    /// No-ops if a match is already in flight.
    func identify(samples: [Float], sampleRate: Float) {
        guard !isMatching else { return }
        isMatching = true
        Task.detached(priority: .utility) { [samples, sampleRate] in
            guard let sig = Self.makeSignature(samples: samples, sampleRate: sampleRate) else {
                await MainActor.run { self.isMatching = false }
                return
            }
            await MainActor.run { self.session.match(sig) }
        }
    }

    func reset() {
        match = nil
        isMatching = false
    }

    // MARK: - Signature generation (background thread)

    private nonisolated static func makeSignature(samples: [Float], sampleRate: Float) -> SHSignature? {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: false
        ) else { return nil }

        let frameCount = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        samples.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }

        let generator = SHSignatureGenerator()
        do {
            try generator.append(buffer, at: nil)
            return try generator.signature()
        } catch {
            return nil
        }
    }
}

// MARK: - SHSessionDelegate

extension ShazamService: SHSessionDelegate {
    nonisolated func session(_ session: SHSession, didFind match: SHMatch) {
        let item = match.mediaItems.first
        Task { @MainActor in
            self.match = item
            self.isMatching = false
        }
    }

    nonisolated func session(
        _ session: SHSession,
        didNotFindMatchFor signature: SHSignature,
        error: (any Error)?
    ) {
        Task { @MainActor in
            self.isMatching = false
        }
    }
}
