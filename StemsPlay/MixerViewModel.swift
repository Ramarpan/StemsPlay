////
////  MixerViewModel.swift
////  StemsPlay
////
////  Created by Ramarpan on 19/01/26.
////


import Foundation
import Combine




@MainActor
final class MixerViewModel: ObservableObject {

    @Published var tracks: [StemTrack] = []
    private let engine: StemAudioEngine
    @Published var transportTime: TimeInterval = 0
//    private var playheadTimer: Timer?
    @Published var playhead: CGFloat = 0  // 0.0 → 1.0
    @Published var currentTimeText: String = "00:00.00"
    @Published var durationText: String = "00:00.00"
    @Published var hasLoadedTracks = false
    @Published var isScrubbing: Bool = false
//    @Published private(set) var transportTime: TimeInterval = 0
    private var wasPlayingBeforeScrub = false
    @Published var isPlaying = false
    @Published var isStopped = false
    private var displayTimer: Timer?

    
    init(engine: StemAudioEngine) {
        self.engine = engine
        self.tracks = engine.tracks
    }

    func loadFolder(url: URL) async {
        // 🔁 RESET TRANSPORT
        displayTimer?.invalidate()
        displayTimer = nil

            transportTime = 0
            playhead = 0
            currentTimeText = "00:00.00"
//            isScrubbing = false

        engine.loadFolder(url: url)
        tracks = engine.tracks
        startWaveformGeneration()

        durationText = Self.formatTime(engine.duration)
        hasLoadedTracks = true
    }




    private func format(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = time.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%05.2f", minutes, seconds)
    }

    @MainActor

    private func startDisplayTimer() {
        displayTimer?.invalidate()

        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.isPlaying else { return }

            let time = self.engine.currentTime
            let duration = self.engine.duration
            guard duration > 0 else { return }

            self.playhead = CGFloat(time / duration)
            self.currentTimeText = Self.formatTime(time)
        }
    }

    
    private func startPlayheadTimer() {
        displayTimer?.invalidate()

        displayTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 30.0,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            guard self.isPlaying, !self.isScrubbing else { return }

            self.transportTime += 1.0 / 30.0

            let duration = self.engine.duration
            guard duration > 0 else { return }

            self.playhead = CGFloat(self.transportTime / duration)
            self.currentTimeText = Self.formatTime(self.transportTime)
        }
    }


    
    
    private static func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = time.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%05.2f", minutes, seconds)
    }



//    func stop() {
//        playheadTimer?.invalidate()
//        playheadTimer = nil
//
//        engine.stop()
//
//        transportTime = 0
//        playhead = 0
//        currentTimeText = "00:00.00"
//
//        isPlaying = false
//        isStopped = true
//    }







    func play() {
        guard !isPlaying else { return }

        engine.reposition(to: transportTime, playImmediately: true)
        isPlaying = true
        startPlayheadTimer()
    }



    func stop() {
        engine.stop()
        displayTimer?.invalidate()
        displayTimer = nil

        transportTime = 0
        playhead = 0
        currentTimeText = "00:00.00"

        isPlaying = false
    }
    
    
    func beginScrubbing(to progress: CGFloat) {
        wasPlayingBeforeScrub = isPlaying
        isScrubbing = true

        if isPlaying {
            engine.stop()
            displayTimer?.invalidate()
            isPlaying = false
        }

        transportTime = engine.duration * Double(progress)
        playhead = progress
        currentTimeText = Self.formatTime(transportTime)
    }




    func endScrubbing(at progress: CGFloat) {
        isScrubbing = false

        let time = engine.duration * Double(progress)
        transportTime = time
        playhead = progress
        currentTimeText = Self.formatTime(time)

        if wasPlayingBeforeScrub {
            engine.reposition(to: time, playImmediately: true)
            isPlaying = true
            startPlayheadTimer()
        }
    }



 
    func seekOnly(to progress: CGFloat) {
        let clamped = min(max(progress, 0), 1)

        playhead = clamped
        transportTime = engine.duration * Double(clamped)
        currentTimeText = Self.formatTime(transportTime)
    }


    
    func setVolume(_ value: Float, for track: StemTrack) {
        engine.setVolume(for: track.name, volume: value)
    }

    func toggleMute(_ track: StemTrack) {
        let newValue = !track.isMuted

        engine.mute(trackName: track.name, isMuted: newValue)

        updateTrack(track.id) {
            $0.isMuted = newValue
        }
    }

    func toggleSolo(_ track: StemTrack) {
        let newValue = !track.isSolo

        engine.solo(trackName: track.name, isSolo: newValue)

        updateTrack(track.id) {
            $0.isSolo = newValue
        }
    }

    // MARK: - Waveforms

    private func startWaveformGeneration() {
        for track in tracks {
            generateWaveform(for: track)
        }
    }

    private func generateWaveform(for track: StemTrack) {
        let id = track.id
        let url = track.fileURL
        let name = track.name

        Task.detached(priority: .utility) {
            do {
                print("▶️ Starting waveform extraction:", name)
                let waveform = try await WaveformExtractor.extract(from: url)

                await MainActor.run {
                    self.updateTrack(id) {
                        $0.waveform = waveform
                    }
                    print("🟢 Applied waveform to:", name)
                }

            } catch {
                print("❌ Waveform extraction failed for \(name):", error)
            }
        }
    }

    // MARK: - Safe MainActor Mutation

    private func updateTrack(
        _ id: UUID,
        mutate: (inout StemTrack) -> Void
    ) {
        guard let index = tracks.firstIndex(where: { $0.id == id }) else { return }
        mutate(&tracks[index])
    }
}
