//
//  StemAudioEngine.swift
//  StemsPlay
//
//  Created by Ramarpan on 19/01/26.


import Foundation
import AVFoundation

final class StemTrack: ObservableObject, Identifiable {

    let id = UUID()
    let name: String
    let fileURL: URL
    let file: AVAudioFile
    let player: AVAudioPlayerNode
    let mixer: AVAudioMixerNode

    
    
    
    // UI STATE (must be mutable, must persist)
    @Published var waveform: WaveformData? = nil
    @Published var isMuted: Bool = false
    @Published var isSolo: Bool = false

    init(
        name: String,
        fileURL: URL,
        file: AVAudioFile,
        player: AVAudioPlayerNode,
        mixer: AVAudioMixerNode
    ) {
        self.name = name
        self.fileURL = fileURL
        self.file = file
        self.player = player
        self.mixer = mixer
    }
}

final class StemAudioEngine {
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private(set) var tracks: [StemTrack] = []
    private var startHostTime: UInt64?

    
    
    init() {
        engine.attach(mixer)
        engine.connect(mixer, to:engine.mainMixerNode, format: nil)
        do {
            try engine.start()
            print("StemAudioEngine: audio engine started safely")
        }catch{
            print("StemAudioEngine: failed to start audio engine",error)
        }
    }
    
    func loadFolder(url:URL){
      
        // clear existing players
        for track in tracks {
            track.player.stop()
            engine.detach(track.player)
            engine.detach(track.mixer)
        }
        tracks.removeAll()
        
        // Find auudio files in folder
        let fileManager = FileManager.default
        
        let audioExtensions = ["wav", "aif", "aiff", "mp3", "m4a"]
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        ) else {
            print("Failed to read folder contents")
            return
        }
        
        let audioFiles = files.filter{
            audioExtensions.contains($0.pathExtension.lowercased())
        }
        
        print("Found \(audioFiles.count) audio files")
        
        
        // Create one player per file
        for fileURL in audioFiles {
            do{
                let audioFile = try AVAudioFile(forReading: fileURL)
                let player = AVAudioPlayerNode()
                let trackMixer = AVAudioMixerNode()
                
                engine.attach(player)
                engine.attach(trackMixer)
                
                engine.connect(player, to:trackMixer, format: audioFile.processingFormat)
                engine.connect(trackMixer, to:mixer, format: audioFile.processingFormat)
                player.scheduleFile(audioFile, at: nil)
                
                let track = StemTrack(
                    name: fileURL.lastPathComponent,
                    fileURL: fileURL,
                    file: audioFile,
                    
                    player: player,
                    mixer: trackMixer
                    
                )
                
                tracks.append(track)
                print("Loaded:", track.name)
            }catch{
                print("Failed to load: ", fileURL.lastPathComponent, error)
            }
        }
        
    }
    
    func play(){
        engine.prepare()
        let startTime = AVAudioTime(hostTime: mach_absolute_time())
        
        
        for track in tracks {
            track.player.play(at:startTime)
        }
        print("Playback started")
    }
    
    func seek(to time: TimeInterval) {

        for track in tracks {
            track.player.stop()

            let sampleRate = track.file.processingFormat.sampleRate
            let startFrame = AVAudioFramePosition(time * sampleRate)
            let remainingFrames =
                track.file.length - startFrame

            guard remainingFrames > 0 else { continue }

            track.player.scheduleSegment(
                track.file,
                startingFrame: startFrame,
                frameCount: AVAudioFrameCount(remainingFrames),
                at: nil
            )
        }

        let startTime = AVAudioTime(hostTime: mach_absolute_time())
        for track in tracks {
            track.player.play(at: startTime)
        }
    }
    
    func pause(){
        for track in tracks {
            track.player.pause()
        }
        print("Playback paused")
    }
    
    func stop() {
        for track in tracks {
            track.player.stop()
        }
        print("Playback stopped")
    }


    
    // MARK: - Playback Timing

    // MARK: - Playback Timing

    var duration: TimeInterval {
        tracks
            .map { Double($0.file.length) / $0.file.processingFormat.sampleRate }
            .max() ?? 0
    }

    var currentTime: TimeInterval {
        guard
            let track = tracks.first,
            let nodeTime = track.player.lastRenderTime,
            let playerTime = track.player.playerTime(forNodeTime: nodeTime)
        else { return 0 }

        return Double(playerTime.sampleTime) / playerTime.sampleRate
    }


    
    func setVolume(for trackName:String, volume:Float){
        guard let index = tracks.firstIndex(where: {$0.name==trackName}) else{return}
        tracks[index].mixer.outputVolume = volume
    }
    
    func mute(trackName: String, isMuted: Bool){
        guard let index = tracks.firstIndex(where: {$0.name==trackName}) else{return}
        tracks[index].isMuted = isMuted
        applySoloMuteLogic()
    }
    
    func solo(trackName:String, isSolo: Bool){
        guard let index = tracks.firstIndex(where: {$0.name==trackName}) else{return}
        tracks[index].isSolo = isSolo
        applySoloMuteLogic()
    }
    
    private func applySoloMuteLogic(){
        let anySoloed = tracks.contains(where :{$0.isSolo})
        
        for i in tracks.indices{
            let track = tracks[i]
            
            if anySoloed{
                tracks[i].mixer.outputVolume = track.isSolo ? 1.0 : 0.0
            } else {
                tracks[i].mixer.outputVolume = track.isMuted ? 0.0: 1.0
            }
        }
    }
}
