import SwiftUI

// MARK: - OverlayView

struct OverlayView: View {
    @ObservedObject var vm: SparkyViewModel

    @State private var pulse = false
    @State private var offset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        ZStack(alignment: .leading) {
            // Card background
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 4)

            HStack(spacing: 12) {
                // State orb
                OrbView(state: vm.state, pulse: pulse)

                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.state.label)
                        .font(AppTheme.labelFont)
                        .foregroundColor(.white.opacity(0.9))

                    Text(displayText)
                        .font(AppTheme.transcriptFont)
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
        }
        .frame(width: AppTheme.overlayWidth, height: AppTheme.overlayHeight)
        .offset(offset)
        .gesture(dragGesture)
        .onAppear { startPulse() }
        .animation(.easeInOut(duration: 0.3), value: vm.state)
        .onTapGesture(count: 2) {
            OverlayWindowController.shared.hide()
        }
    }

    // MARK: - Helpers

    private var displayText: String {
        if !vm.response.isEmpty { return vm.response }
        if !vm.transcript.isEmpty { return vm.transcript }
        return "Say 'Hey Sparky' to start"
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                offset = value.translation
            }
            .onEnded { _ in
                isDragging = false
                // Commit offset to window position instead
                OverlayWindowController.shared.translate(by: offset)
                offset = .zero
            }
    }
}

// MARK: - OrbView

struct OrbView: View {
    let state: SparkyState
    let pulse: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(state.color.opacity(0.2))
                .frame(width: AppTheme.orb, height: AppTheme.orb)

            Circle()
                .fill(state.color.opacity(pulse && state != .idle ? 0.5 : 0.8))
                .frame(width: AppTheme.orb * 0.6, height: AppTheme.orb * 0.6)
                .scaleEffect(pulse && state == .listening ? 1.15 : 1.0)

            // Wave bars for speaking/listening
            if state == .listening || state == .speaking {
                WaveBars(color: state.color)
                    .frame(width: AppTheme.orb * 0.5, height: AppTheme.orb * 0.35)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state)
    }
}

// MARK: - WaveBars

struct WaveBars: View {
    let color: Color
    @State private var anim = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(width: 2.5, height: anim ? CGFloat.random(in: 6...14) : 4)
                    .animation(
                        .easeInOut(duration: Double.random(in: 0.3...0.6))
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.1),
                        value: anim
                    )
            }
        }
        .onAppear { anim = true }
    }
}
