import SwiftUI

private let controlColumnWidth: CGFloat = 90
private let waveformHeight: CGFloat = 60
private let playheadWidth: CGFloat = 2




struct ContentView: View {


    @StateObject private var mixerVM: MixerViewModel

    init() {
        let engine = StemAudioEngine()
        _mixerVM = StateObject(wrappedValue: MixerViewModel(engine: engine))
    }


    var body: some View {
        VStack(spacing: 20) {

            Text("Stems Play")
                .font(.title)

            HStack(spacing: 12) {
                Button("Load Folder") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false

                    if panel.runModal() == .OK, let url = panel.url {
                        Task {
                            await mixerVM.loadFolder(url: url)
                        }
                    }
                }

                Button("Play") {
                    mixerVM.play()
                }
                Button("Stop") {
                    mixerVM.stop()
                }
            }

            // 🔹 GLOBAL PLAYHEAD CONTAINER
            ZStack(alignment: .topLeading) {

                List {
                    ForEach(mixerVM.tracks) { track in
                        TrackRow(
                            track: track,
                            controlColumnWidth: controlColumnWidth,
                            waveformHeight: waveformHeight,
                            onMute: { mixerVM.toggleMute(track) },
                            onSolo: { mixerVM.toggleSolo(track) },
                            onVolumeChange: { mixerVM.setVolume($0, for: track) }
                        )
                    }
                }

                


                // MARK: - SINGLE GLOBAL PLAYHEAD + SCRUBBING
                if mixerVM.hasLoadedTracks {
                    GeometryReader { geo in
                        let waveformWidth = geo.size.width - controlColumnWidth - 12
                        let x =
                            controlColumnWidth + 12 +
                            waveformWidth * mixerVM.playhead

                        ZStack(alignment: .topLeading) {

                            // PLAYHEAD LINE
                            Rectangle()
                                .fill(Color.white.opacity(0.85))
                                .frame(width: playheadWidth)
                                .frame(maxHeight: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/)
                                .offset(x: x)
                                .allowsHitTesting(false)

                            // TIME LABEL
                            Text(mixerVM.currentTimeText)
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                                .offset(x: x - 20, y: -18)

                            // SCRUBBING LAYER (transparent)
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .frame(
                                    width: waveformWidth,
                                    height: CGFloat(mixerVM.tracks.count) * (waveformHeight + 16)
                                )
                                .offset(x: controlColumnWidth + 12)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let localX = value.location.x - (controlColumnWidth + 12)

                                            let progress =
                                                min(
                                                    max(localX / waveformWidth, 0),
                                                    1
                                                )

                                            mixerVM.beginScrubbing(to: progress)
                                        }
                                        .onEnded { _ in
                                            mixerVM.endScrubbing()
                                        }
                                ) 
                        }
                    }
                   
                }



            }
            .frame(minHeight: 300)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
