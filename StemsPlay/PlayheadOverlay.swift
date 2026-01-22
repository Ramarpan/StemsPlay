import SwiftUI

struct PlayheadOverlay: View {

    let controlColumnWidth: CGFloat
    let waveformHeight: CGFloat
    let playheadWidth: CGFloat

    @ObservedObject var mixerVM: MixerViewModel

    private func clampToProgress(_ x: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let raw = x / totalWidth
        return min(max(raw, 0), 1)
    }


    var body: some View {
        GeometryReader { geo in
            let waveformWidth = geo.size.width - controlColumnWidth - 12
            let x = controlColumnWidth + 12 + waveformWidth * mixerVM.playhead

            ZStack(alignment: .topLeading) {

                Rectangle()
                    .fill(Color.white)
                    .frame(width: playheadWidth)
                    .frame(maxHeight: .infinity)
                    .offset(x: x)
                    .allowsHitTesting(false)

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let progress = clampToProgress(
                                    value.location.x - (controlColumnWidth + 12),
                                    totalWidth: waveformWidth
                                )
                                mixerVM.beginScrubbing(to: progress)
                            }
                            .onEnded { value in
                                let progress = clampToProgress(
                                    value.location.x - (controlColumnWidth + 12),
                                    totalWidth: waveformWidth
                                )
                                mixerVM.endScrubbing(at: progress)
                            }
                    )
            }
        }
    }
    // MARK: - Helper

//    private func clampToProgress(
//        _ x: CGFloat,
//        totalWidth: CGFloat
//    ) -> CGFloat {
//        let raw = x / totalWidth
//        return min(max(raw, 0), 1)
//    }
}
