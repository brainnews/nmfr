import SwiftUI

// MARK: - Settings

struct VisualizerSettings: Equatable {
    var colorMode: String
    var solidColor: StorableColor
    var crtEnabled: Bool
    var glitchEnabled: Bool
    var pixelatedEnabled: Bool
}

// MARK: - VisualizerView

struct VisualizerView: View {
    let player: RadioPlayer
    let isPlaying: Bool
    let settings: VisualizerSettings

    @Environment(\.colorScheme) private var colorScheme

    private var brightness: Double { colorScheme == .dark ? 1.0 : 0.55 }
    private var dimBrightness: Double { colorScheme == .dark ? 0.9 : 0.5 }

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { context in
            Canvas { ctx, size in
                let now = context.date.timeIntervalSinceReferenceDate
                let samples = player.currentWaveform
                let hasSignal = player.hasAudioSignal
                if samples.isEmpty || !hasSignal {
                    drawAnimatedWave(ctx: ctx, size: size, time: now, hueOffset: 0,  alpha: 0.35, phase: 1.0)
                    drawAnimatedWave(ctx: ctx, size: size, time: now, hueOffset: 60, alpha: 0.18, phase: 1.4)
                    if settings.crtEnabled {
                        drawCRT(ctx: ctx, size: size)
                    }
                } else {
                    drawOscilloscope(ctx: ctx, size: size, time: now, samples: samples)
                    if settings.crtEnabled {
                        drawCRT(ctx: ctx, size: size)
                    }
                    if settings.glitchEnabled {
                        drawGlitch(ctx: ctx, size: size, time: now, samples: samples)
                    }
                }
            }
        }
    }

    // MARK: - Color helper

    private func waveColor(time: Double, hueBase: Double, saturation: Double, opacity: Double) -> Color {
        if settings.colorMode == "solid" {
            return settings.solidColor.color.opacity(opacity)
        }
        let hue = (time * 20 + hueBase).truncatingRemainder(dividingBy: 360) / 360
        return Color(hue: hue, saturation: saturation, brightness: brightness, opacity: opacity)
    }

    private func dimWaveColor(time: Double, hueBase: Double, saturation: Double, opacity: Double) -> Color {
        if settings.colorMode == "solid" {
            return settings.solidColor.color.opacity(opacity)
        }
        let hue = (time * 20 + hueBase).truncatingRemainder(dividingBy: 360) / 360
        return Color(hue: hue, saturation: saturation, brightness: dimBrightness, opacity: opacity)
    }

    // MARK: - Oscilloscope waveform (signed time-domain samples)

    private func drawOscilloscope(ctx: GraphicsContext, size: CGSize, time: Double, samples: [Float]) {
        let count = samples.count
        guard count > 1 else { return }

        let midY   = size.height / 2
        let maxAmp = size.height * 0.44

        func makePath(xOffset: Double) -> Path {
            var path = Path()
            for i in 0..<count {
                let rawX = size.width * Double(i) / Double(count - 1) + xOffset
                let raw  = max(-1.0, min(1.0, Double(samples[i]) * 3.0))
                let rawY = midY - maxAmp * raw

                let pt: CGPoint
                if settings.crtEnabled {
                    pt = barrelDistort(CGPoint(x: rawX, y: rawY), size: size)
                } else {
                    pt = CGPoint(x: rawX, y: rawY)
                }

                if i == 0 {
                    path.move(to: pt)
                } else {
                    let prevI = i - 1
                    let prevRaw = max(-1.0, min(1.0, Double(samples[prevI]) * 3.0))
                    let prevRawX = size.width * Double(prevI) / Double(count - 1) + xOffset
                    let prevRawY = midY - maxAmp * prevRaw
                    let prevPt: CGPoint
                    if settings.crtEnabled {
                        prevPt = barrelDistort(CGPoint(x: prevRawX, y: prevRawY), size: size)
                    } else {
                        prevPt = CGPoint(x: prevRawX, y: prevRawY)
                    }
                    let cpX = (prevPt.x + pt.x) / 2
                    path.addCurve(
                        to: pt,
                        control1: CGPoint(x: cpX, y: prevPt.y),
                        control2: CGPoint(x: cpX, y: pt.y)
                    )
                }
            }
            return path
        }

        let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)

        if settings.pixelatedEnabled {
            for i in 0..<count {
                let rawX = size.width * Double(i) / Double(count - 1)
                let raw  = max(-1.0, min(1.0, Double(samples[i]) * 1.5))
                let x    = (rawX / 4.0).rounded() * 4.0
                let y    = ((midY - maxAmp * raw) / 4.0).rounded() * 4.0
                let block = Path(CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
                ctx.fill(block, with: .color(waveColor(time: time, hueBase: 0, saturation: 0.7, opacity: 0.75)))
            }
        } else {
            let path1 = makePath(xOffset: 0)
            let path2 = makePath(xOffset: 4)
            ctx.stroke(path2, with: .color(dimWaveColor(time: time, hueBase: 50, saturation: 0.55, opacity: 0.10)), style: stroke)
            ctx.stroke(path1, with: .color(waveColor(time: time, hueBase: 0, saturation: 0.7, opacity: 0.25)), style: stroke)
            ctx.stroke(path1, with: .color(waveColor(time: time, hueBase: 0, saturation: 0.5, opacity: 0.06)),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

            if settings.crtEnabled {
                ctx.stroke(makePath(xOffset: -2), with: .color(.red.opacity(0.07)), style: stroke)
                ctx.stroke(makePath(xOffset:  2), with: .color(.blue.opacity(0.05)), style: stroke)
            }
        }
    }

    // MARK: - Animated sine fallback

    private func drawAnimatedWave(
        ctx: GraphicsContext, size: CGSize, time: Double,
        hueOffset: Double, alpha: Double, phase: Double
    ) {
        let midY  = size.height / 2
        let steps = Int(size.width / 2)

        var path = Path()
        for i in 0...steps {
            let x = size.width * Double(i) / Double(steps)
            let p = Double(i) / Double(steps)
            var y = midY + size.height * 0.45 * (
                sin(p * .pi * 4 + time * 2.0 * phase) * 0.35 +
                sin(p * .pi * 7 + time * 1.3 * phase) * 0.18 +
                sin(p * .pi * 2.5 + time * 0.8 * phase) * 0.12
            )
            if settings.pixelatedEnabled {
                let snapX = (x / 4.0).rounded() * 4.0
                y = (y / 4.0).rounded() * 4.0
                i == 0 ? path.move(to: CGPoint(x: snapX, y: y)) : path.addLine(to: CGPoint(x: snapX, y: y))
            } else {
                i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        ctx.stroke(path, with: .color(dimWaveColor(time: time, hueBase: hueOffset, saturation: 0.6, opacity: alpha)),
                   style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        ctx.stroke(path, with: .color(waveColor(time: time, hueBase: hueOffset, saturation: 0.5, opacity: alpha * 0.4)),
                   style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }

    // MARK: - CRT Overlay

    private func barrelDistort(_ pt: CGPoint, size: CGSize) -> CGPoint {
        let nx = (pt.x - size.width / 2)  / (size.width / 2)
        let ny = (pt.y - size.height / 2) / (size.height / 2)
        let r2 = nx * nx + ny * ny
        let f  = 1 + 0.08 * r2
        return CGPoint(
            x: size.width / 2  + nx * f * (size.width / 2),
            y: size.height / 2 + ny * f * (size.height / 2)
        )
    }

    private func drawCRT(ctx: GraphicsContext, size: CGSize) {
        // Scanlines
        var y = 0.0
        while y < size.height {
            let line = Path(CGRect(x: 0, y: y, width: size.width, height: 1))
            ctx.fill(line, with: .color(.black.opacity(0.25)))
            y += 3
        }
    }

    // MARK: - Glitch Overlay

    private func drawGlitch(ctx: GraphicsContext, size: CGSize, time: Double, samples: [Float]) {
        let glitchCycle = (time * 2.3).truncatingRemainder(dividingBy: 1.0)
        guard glitchCycle < 0.15 else { return }

        let sliceCount = 6
        let sliceH = size.height / Double(sliceCount)
        let count = samples.count
        guard count > 1 else { return }

        let midY   = size.height / 2
        let maxAmp = size.height * 0.44

        for i in 0..<sliceCount {
            let seed = Double(i) * 137.508 + time * 31.41
            let rand = (sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1.0)
            guard abs(rand) > 0.45 else { continue }

            let displacement = rand * size.width * 0.08
            let sliceRect = CGRect(x: 0, y: Double(i) * sliceH, width: size.width, height: sliceH)

            ctx.drawLayer { inner in
                inner.clip(to: Path(sliceRect))
                inner.translateBy(x: displacement, y: 0)

                var path = Path()
                for j in 0..<count {
                    let x = size.width * Double(j) / Double(count - 1)
                    let raw = max(-1.0, min(1.0, Double(samples[j]) * 3.0))
                    let y = midY - maxAmp * raw
                    j == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                }
                inner.stroke(
                    path,
                    with: .color(waveColor(time: time, hueBase: 0, saturation: 0.7, opacity: 0.4)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
            }

            let stripe = Path(CGRect(x: 0, y: Double(i) * sliceH, width: size.width, height: 1))
            ctx.fill(stripe, with: .color(.red.opacity(0.15 * abs(rand))))
        }
    }
}

// MARK: - Idle flat line

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
