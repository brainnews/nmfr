import Foundation
import MediaPlayer
import AppKit

@MainActor
class NowPlayingManager {
    static let shared = NowPlayingManager()

    private var currentStation: Station?
    private var artworkImage: NSImage?

    func update(station: Station?, isPlaying: Bool) {
        currentStation = station
        var info: [String: Any] = [:]

        if let station {
            info[MPMediaItemPropertyTitle] = station.name
            info[MPMediaItemPropertyArtist] = [station.country, station.tags]
                .filter { !$0.isEmpty }
                .prefix(2)
                .joined(separator: " · ")
            info[MPMediaItemPropertyMediaType] = MPMediaType.anyAudio.rawValue
            info[MPNowPlayingInfoPropertyIsLiveStream] = true
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

            // Use cached artwork or load async
            if let img = artworkImage {
                let artwork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
                info[MPMediaItemPropertyArtwork] = artwork
            } else {
                loadArtwork(for: station)
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .stopped
    }

    func setupRemoteCommands(player: RadioPlayer) {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak player] _ in
            guard let player else { return .commandFailed }
            Task { @MainActor in player.togglePlayStop() }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak player] _ in
            guard let player else { return .commandFailed }
            Task { @MainActor in player.stop() }
            return .success
        }

        commandCenter.stopCommand.addTarget { [weak player] _ in
            guard let player else { return .commandFailed }
            Task { @MainActor in player.stop() }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak player] _ in
            guard let player else { return .commandFailed }
            Task { @MainActor in player.togglePlayStop() }
            return .success
        }
    }

    private func loadArtwork(for station: Station) {
        guard let url = station.faviconURL else { return }
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let img = NSImage(data: data) {
                await MainActor.run {
                    self.artworkImage = img
                    if self.currentStation?.url == station.url {
                        self.update(station: station, isPlaying: true)
                    }
                }
            }
        }
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        artworkImage = nil
    }
}
