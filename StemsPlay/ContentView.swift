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

            // MARK: - Title
            Text("Stems Play")
                .font(.title)

            // MARK: - Transport Controls
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

            // MARK: - TRACKS + PLAYHEAD (SINGLE SCROLL CONTEXT)
            ScrollView {
                ZStack(alignment: .topLeading) {

                    // 1️⃣ TRACK LIST
                    LazyVStack(spacing: 16) {
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
                    .padding(.vertical, 8)

                    // 2️⃣ PLAYHEAD OVERLAY (SCROLLS WITH CONTENT)
                    if mixerVM.hasLoadedTracks {
                        PlayheadOverlay(
                            controlColumnWidth: controlColumnWidth,
                            waveformHeight: waveformHeight,
                            playheadWidth: playheadWidth,
                            mixerVM: mixerVM
                        )
                        .allowsHitTesting(true) // scrubbing must receive touches
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

