import SwiftUI

struct VisualizerView: View {
    let player: RadioPlayer   // read currentWaveform / hasAudioSignal each frame inside Canvas
    let isPlaying: Bool

    @Environment(\.colorScheme) private var colorScheme

    // In Light Mode, full brightness makes yellows/greens invisible; dial it down.
    private var brightness: Double { colorScheme == .dark ? 1.0 : 0.55 }
    private var dimBrightness: Double { colorScheme == .dark ? 0.9 : 0.5 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30, paused: !isPlaying)) { context in
            Canvas { ctx, size in
                let now = context.date.timeIntervalSinceReferenceDate
                // Read directly from the tap each frame — no @Published, no extra re-renders
                let samples = player.currentWaveform
                let hasSignal = player.hasAudioSignal
                if samples.isEmpty || !hasSignal {
                    drawAnimatedWave(ctx: ctx, size: size, time: now, hueOffset: 0,  alpha: 0.35, phase: 1.0)
                    drawAnimatedWave(ctx: ctx, size: size, time: now, hueOffset: 60, alpha: 0.18, phase: 1.4)
                } else {
                    drawOscilloscope(ctx: ctx, size: size, time: now, samples: samples)
                }
            }
        }
    }

    // MARK: - Oscilloscope waveform (signed time-domain samples)

    private func drawOscilloscope(ctx: GraphicsContext, size: CGSize, time: Double, samples: [Float]) {
        let count = samples.count
        guard count > 1 else { return }

        let hue1 = (time * 20).truncatingRemainder(dividingBy: 360) / 360
        let hue2 = (time * 20 + 50).truncatingRemainder(dividingBy: 360) / 360
        let midY   = size.height / 2
        let maxAmp = size.height * 0.44

        func makePath(xOffset: Double) -> Path {
            var path = Path()
            for i in 0..<count {
                let x    = size.width * Double(i) / Double(count - 1) + xOffset
                let raw  = max(-1.0, min(1.0, Double(samples[i]) * 3.0))
                let y    = midY - maxAmp * raw
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    let prevRaw = max(-1.0, min(1.0, Double(samples[i - 1]) * 3.0))
                    let prevX = size.width * Double(i - 1) / Double(count - 1) + xOffset
                    let prevY = midY - maxAmp * prevRaw
                    let cpX   = (prevX + x) / 2
                    path.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: cpX, y: prevY),
                        control2: CGPoint(x: cpX, y: y)
                    )
                }
            }
            return path
        }

        let path1 = makePath(xOffset: 0)
        let path2 = makePath(xOffset: 4)

        let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)

        ctx.stroke(path2, with: .color(Color(hue: hue2, saturation: 0.55, brightness: dimBrightness, opacity: 0.10)), style: stroke)
        ctx.stroke(path1, with: .color(Color(hue: hue1, saturation: 0.7, brightness: brightness, opacity: 0.25)), style: stroke)
        ctx.stroke(path1, with: .color(Color(hue: hue1, saturation: 0.5, brightness: brightness, opacity: 0.06)),
                   style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Animated sine fallback

    private func drawAnimatedWave(
        ctx: GraphicsContext, size: CGSize, time: Double,
        hueOffset: Double, alpha: Double, phase: Double
    ) {
        let hue   = (time * 25 + hueOffset).truncatingRemainder(dividingBy: 360) / 360
        let color = Color(hue: hue, saturation: 0.6, brightness: dimBrightness, opacity: alpha)
        let midY  = size.height / 2
        let steps = Int(size.width / 2)

        var path = Path()
        for i in 0...steps {
            let x = size.width * Double(i) / Double(steps)
            let p = Double(i) / Double(steps)
            let y = midY + size.height * 0.45 * (
                sin(p * .pi * 4 + time * 2.0 * phase) * 0.35 +
                sin(p * .pi * 7 + time * 1.3 * phase) * 0.18 +
                sin(p * .pi * 2.5 + time * 0.8 * phase) * 0.12
            )
            i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        ctx.stroke(path, with: .color(color),
                   style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        ctx.stroke(path, with: .color(Color(hue: hue, saturation: 0.5, brightness: brightness, opacity: alpha * 0.4)),
                   style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }
}

struct IdleVisualizerView: View {
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            ctx.stroke(path, with: .color(.primary.opacity(0.1)), style: StrokeStyle(lineWidth: 1))
        }
    }
}
