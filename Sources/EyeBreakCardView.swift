import SwiftUI

/// Floating countdown card displayed during 20-20-20 eye health breaks.
struct EyeBreakCardView: View {
    let secondsRemaining: Int
    let totalDuration: Int
    let onSkip: () -> Void

    private var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return Double(secondsRemaining) / Double(totalDuration)
    }

    var body: some View {
        HStack(spacing: 16) {
            // ── Circular Countdown Timer ───────────────────────────────────────
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 4.5)
                    .frame(width: 58, height: 58)

                // Animated Progress Ring
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        LinearGradient(
                            colors: [Theme.cyan, Theme.neonVolt],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )
                    .frame(width: 58, height: 58)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: secondsRemaining)

                // Countdown Digits
                VStack(spacing: -2) {
                    Text("\(secondsRemaining)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.neonVolt)
                        .contentTransition(.numericText())
                    Text("SEC")
                        .font(.system(size: 7.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                }
            }

            // ── Content Info ──────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.cyan)
                        Text("20-20-20 RULE")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(Theme.cyan)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Theme.cyan.opacity(0.12))
                    .clipShape(Capsule())

                    Spacer()

                    // Skip button
                    Button(action: onSkip) {
                        HStack(spacing: 3) {
                            Text("Skip")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Text("Look 20 feet away")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Relax your eye muscles by focusing on something in the distance.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 360)
        .background(
            ZStack {
                // Frosted Dark Glass Layer
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.11).opacity(0.96))

                // Subtle Glow
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.cyan.opacity(0.4), Theme.neonVolt.opacity(0.3), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
        .shadow(color: Theme.cyan.opacity(0.15), radius: 16, x: 0, y: 4)
    }
}
