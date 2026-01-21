//
//  WaveformView.swift
//  StemsPlay
//
//  Created by Ramarpan on 19/01/26.
//

import Foundation
import SwiftUI

struct WaveformView: View {
    let waveform: WaveformData
    let color: Color

    var body: some View {
        Canvas { context, size in
            let samples = waveform.samples
            guard !samples.isEmpty else { return }

            let midY = size.height / 2
            let step = size.width / CGFloat(samples.count)

            var path = Path()

            for (index, amp) in samples.enumerated() {
                let x = CGFloat(index) * step
                let y = CGFloat(max(-1, min(1, amp))) * midY
                path.move(to: CGPoint(x: x, y: midY - y))
                path.addLine(to: CGPoint(x: x, y: midY + y))
            }

            context.stroke(path, with: .color(color), lineWidth: 1)
        }
    }
}

