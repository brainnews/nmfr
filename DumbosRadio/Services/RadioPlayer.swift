import AVFoundation
import AppKit
import Combine
import ShazamKit

enum PlaybackState: Equatable {
    case idle
    case loading
    case playing
    case error(String)

    var isPlaying: Bool { self == .playing }
    var isLoading: Bool { self == .loading }

    var statusText: String? {
        switch self {
        case .loading: return "Buffering..."
        case .error(let msg): return msg
        default: return nil
        }
    }
}

@MainActor
class RadioPlayer: ObservableObject {
    @Published var state: PlaybackState = .idle
    @Published var currentStation: Station?
    /// Current song/track title from ICY/HLS stream metadata, if the stream provides it.
    @Published var streamTitle: String?
    /// Most recent Shazam match for the currently playing audio, or nil.
    @Published var shazamMatch: SHMediaItem? = nil
    @Published var isShazamMatching: Bool = false

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var bufferingObservation: NSKeyValueObservation?
    private var audioTap: AudioTapProcessor?
    private var metadataOutput: AVPlayerItemMetadataOutput?
    private var metadataDelegate: StreamMetadataDelegate?

    private let persistence: PersistenceManager
    private var cancellables = Set<AnyCancellable>()
    private let shazamService = ShazamService()
    private var shazamCheckTimer: Timer?

    init(persistence: PersistenceManager) {
        self.persistence = persistence
        persistence.$eqSettings
            .sink { [weak self] _ in self?.applyEQ() }
            .store(in: &cancellables)
        // Bridge ShazamService's properties into RadioPlayer's @Published vars
        // so SwiftUI views re-render when a match arrives.
        shazamService.$match
            .sink { [weak self] in self?.shazamMatch = $0 }
            .store(in: &cancellables)
        shazamService.$isMatching
            .sink { [weak self] in self?.isShazamMatching = $0 }
            .store(in: &cancellables)
        // Clear the Shazam match when ICY metadata indicates a track change.
        $streamTitle
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.shazamService.reset()
                self.audioTap?.shazamAccumCount = 0
                self.audioTap?.shazamReady = false
            }
            .store(in: &cancellables)
    }

    // MARK: - Visualizer data (read by Canvas on the main thread each frame — no @Published needed)

    /// Latest signed oscilloscope samples. Read directly by the Canvas inside TimelineView.
    var currentWaveform: [Float] { audioTap?.latestWaveform ?? [] }

    /// True when there is an active audio signal above the noise floor.
    var hasAudioSignal: Bool { audioTap?.latestMagnitudes.max() ?? 0 > 0.001 }

    // MARK: - Playback

    func play(_ station: Station) {
        stop()
        currentStation = station
        state = .loading
        streamTitle = nil
        persistence.lastStation = station

        guard let url = URL(string: station.url) else {
            state = .error("Invalid stream URL")
            return
        }

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 2

        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.volume = Float(persistence.isMuted ? 0 : persistence.volume)
        newPlayer.automaticallyWaitsToMinimizeStalling = false

        playerItem = item
        player = newPlayer

        // Set up audio analysis tap.
        // AVMutableAudioMixInputParameters() with no track sets trackID to
        // kCMPersistentTrackID_Invalid, applying to ALL audio tracks —
        // no track discovery needed, works for ICY/Shoutcast/HLS/MP3.
        shazamService.reset()
        shazamCheckTimer?.invalidate()
        shazamCheckTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkShazamBuffer() }
        }

        let tap = AudioTapProcessor()
        audioTap = tap

        if let processingTap = tap.tap {
            let params = AVMutableAudioMixInputParameters()
            params.audioTapProcessor = processingTap
            let mix = AVMutableAudioMix()
            mix.inputParameters = [params]
            item.audioMix = mix
        }

        applyEQ(to: tap)

        // Capture ICY / HLS stream title metadata (e.g. current song).
        let delegate = StreamMetadataDelegate { [weak self] title in
            Task { @MainActor [weak self] in
                self?.streamTitle = title
            }
        }
        let metaOut = AVPlayerItemMetadataOutput(identifiers: nil)
        metaOut.setDelegate(delegate, queue: .main)
        item.add(metaOut)
        metadataOutput = metaOut
        metadataDelegate = delegate

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    newPlayer.play()
                case .failed:
                    let msg = item.error?.localizedDescription ?? "Stream failed"
                    self.state = .error(msg)
                default:
                    break
                }
            }
        }

        timeControlObservation = newPlayer.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch p.timeControlStatus {
                case .playing:
                    self.state = .playing
                case .waitingToPlayAtSpecifiedRate:
                    if case .playing = self.state {
                        self.state = .loading
                    }
                case .paused:
                    if case .playing = self.state { self.state = .idle }
                @unknown default:
                    break
                }
            }
        }
    }

    func stop() {
        statusObservation?.invalidate()
        timeControlObservation?.invalidate()
        bufferingObservation?.invalidate()
        statusObservation = nil
        timeControlObservation = nil
        bufferingObservation = nil

        shazamCheckTimer?.invalidate()
        shazamCheckTimer = nil
        shazamService.reset()

        player?.pause()
        player = nil
        playerItem = nil
        audioTap = nil
        metadataOutput = nil
        metadataDelegate = nil
        streamTitle = nil
        state = .idle
    }

    func togglePlayStop() {
        if state == .idle || state == .loading {
            if let station = currentStation { play(station) }
        } else if case .error = state {
            if let station = currentStation { play(station) }
        } else {
            stop()
        }
    }

    // MARK: - Shazam

    private func checkShazamBuffer() {
        guard case .playing = state,
              let tap = audioTap,
              tap.shazamReady,
              !shazamService.isMatching else { return }
        let count = tap.shazamAccumCount
        let sampleRate = tap.shazamSampleRate
        let samples = Array(tap.shazamAccum.prefix(count))
        // Reset accumulation for the next window
        tap.shazamAccumCount = 0
        tap.shazamReady = false
        shazamService.identify(samples: samples, sampleRate: sampleRate)
    }

    // MARK: - EQ

    /// Called by the Combine subscription whenever eqSettings changes,
    /// and immediately after creating a new tap in play().
    func applyEQ(to tap: AudioTapProcessor? = nil) {
        let target = tap ?? audioTap
        guard let target else { return }
        let settings = persistence.eqSettings
        target.eqEnabled = settings.enabled
        target.eqGains   = settings.gains
        target.eqDirty   = true
    }

    func applyVolume() {
        player?.volume = Float(persistence.isMuted ? 0 : persistence.volume)
    }

    func setFadeVolume(_ fraction: Double) {
        player?.volume = Float(fraction * persistence.volume * (persistence.isMuted ? 0 : 1))
    }

    var isActive: Bool { state == .playing || state == .loading }
}

// MARK: - Stream metadata delegate

private class StreamMetadataDelegate: NSObject, AVPlayerItemMetadataOutputPushDelegate {
    let onTitle: (String?) -> Void

    init(onTitle: @escaping (String?) -> Void) {
        self.onTitle = onTitle
        super.init()
    }

    func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        let title = groups
            .flatMap { $0.items }
            .first { $0.commonKey == .commonKeyTitle }?
            .stringValue
        onTitle(title?.isEmpty == false ? title : nil)
    }
}
