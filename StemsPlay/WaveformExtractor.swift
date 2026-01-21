//
//  WaveformExtractor.swift
//  StemsPlay
//
//  Created by Ramarpan on 19/01/26.
//

import Foundation
import AVFoundation
import Accelerate

struct WaveformData: Equatable {
    let samples: [Float]        // normalized 0…1
    let duration: TimeInterval
    let sampleCount: Int
}


final class WaveformExtractor {

    /// Extracts waveform peaks using AVAssetReader + vDSP
    /// - Parameters:
    ///   - url: audio file URL
    ///   - targetSamples: number of peaks to generate (e.g. 1000–3000)
    static func extract(
        from url: URL,
        targetSamples: Int = 1500
    ) async throws -> WaveformData {

        let asset = AVURLAsset(url: url)
        let durationTime = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(durationTime)
        
        
        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw NSError(domain: "WaveformExtractor", code: -1)
        }

        let reader = try AVAssetReader(asset: asset)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: track,
                                              outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()

        var allSamples: [Float] = []

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer(),
                  let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)
            else { break }

            let length = CMBlockBufferGetDataLength(blockBuffer)
            var buffer = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)

            CMBlockBufferCopyDataBytes(blockBuffer,
                                       atOffset: 0,
                                       dataLength: length,
                                       destination: &buffer)

            allSamples.append(contentsOf: buffer)
            CMSampleBufferInvalidate(sampleBuffer)
        }

        let totalSamples = allSamples.count
        guard totalSamples > 0 else {
            throw NSError(domain: "WaveformExtractor", code: -2)
        }

        let samplesPerBucket = max(1, totalSamples / targetSamples)
        var peaks: [Float] = []
        peaks.reserveCapacity(targetSamples)

        for i in stride(from: 0, to: totalSamples, by: samplesPerBucket) {
            let end = min(i + samplesPerBucket, totalSamples)
            let slice = Array(allSamples[i..<end])

            var rms: Float = 0
            vDSP_rmsqv(slice, 1, &rms, vDSP_Length(slice.count))

            peaks.append(rms)
        }

        // Normalize 0…1
        let maxPeak = peaks.max() ?? 1
        let normalized = peaks.map { $0 / maxPeak }

        return WaveformData(
            samples: normalized,
            duration: durationSeconds,
            sampleCount: normalized.count
        )
    }
}
