import SwiftUI

struct TrackRow: View {

    let track: StemTrack
    let controlColumnWidth: CGFloat
    let waveformHeight: CGFloat

    let onMute: () -> Void
    let onSolo: () -> Void
    let onVolumeChange: (Float) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // LEFT CONTROL COLUMN
            VStack(spacing: 8) {
                Button(track.isMuted ? "Unmute" : "Mute") {
                    onMute()
                }

                Button(track.isSolo ? "Unsolo" : "Solo") {
                    onSolo()
                }

                Slider(
                    value: Binding(
                        get: { track.mixer.outputVolume },
                        set: onVolumeChange
                    ),
                    in: 0...1
                )
            }
            .frame(width: controlColumnWidth)

            // WAVEFORM COLUMN
            VStack(alignment: .leading, spacing: 6) {
                Text(track.name)
                    .font(.headline)

                if let waveform = track.waveform {
                    WaveformView(
                        waveform: waveform,
                        color: .cyan
                    )
                    .frame(height: waveformHeight)
                } else {
                    Text("Loading waveform…")
                        .font(.caption)
                        .frame(height: waveformHeight)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
