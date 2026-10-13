import SwiftUI

// ─── Design Tokens & Theme ───────────────────────────────────────────────────

enum Theme {
    static let bg          = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let card        = Color(red: 0.10, green: 0.10, blue: 0.13)
    static let cardHover   = Color(red: 0.13, green: 0.13, blue: 0.17)
    static let border      = Color.white.opacity(0.07)

    // Vibrant accent colors from reference image
    static let neonVolt    = Color(red: 0.82, green: 1.00, blue: 0.20) // #D2FF33 neon lime
    static let emerald     = Color(red: 0.18, green: 0.87, blue: 0.44) // #2EDE70 vivid green
    static let electric    = Color(red: 1.00, green: 0.38, blue: 0.18) // #FF612E coral/orange
    static let cyan        = Color(red: 0.15, green: 0.65, blue: 1.00) // #26A6FF electric blue

    static let textPrimary = Color.white.opacity(0.95)
    static let textMuted   = Color.white.opacity(0.45)
    static let textDim     = Color.white.opacity(0.25)
}

// ─── Main MenuBar Root View ───────────────────────────────────────────────────

struct MenuBarView: View {
    @ObservedObject var viewModel: TrackerViewModel
    @State private var showSettings: Bool = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if showSettings {
                SettingsView(viewModel: viewModel, showSettings: $showSettings)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                DashboardView(viewModel: viewModel, showSettings: $showSettings)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .frame(width: 380, height: 560)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSettings)
        .colorScheme(.dark)
    }
}

// ─── Dashboard View ───────────────────────────────────────────────────────────

struct DashboardView: View {
    @ObservedObject var viewModel: TrackerViewModel
    @Binding var showSettings: Bool

    var isViewingToday: Bool {
        viewModel.selectedDateString == dateFmt.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 12) {

            // ── Top Bar ───────────────────────────────────────────────────────
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isPaused ? Theme.electric : (viewModel.isIdle ? .orange : Theme.neonVolt))
                        .frame(width: 7, height: 7)
                        .shadow(color: (viewModel.isPaused ? Theme.electric : Theme.neonVolt).opacity(0.6), radius: 4)

                    Text("MacTimer")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                }

                Spacer()

                // Eye Health quick badge
                if viewModel.isEyeCareEnabled {
                    Button {
                        viewModel.triggerEyeCarePreview()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 9, weight: .bold))
                            let mins = max(1, Int(ceil(viewModel.eyeCareTimeRemaining / 60)))
                            Text("\(mins)m")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Theme.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.cyan.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("20-20-20 Eye Health: Next break in \(formatDuration(viewModel.eyeCareTimeRemaining)). Click to start break now.")
                }

                // Pause / Break button
                Button {
                    viewModel.togglePause(minutes: 15)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isPaused ? "play.fill" : "cup.and.saucer.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(viewModel.isPaused ? "Resume" : "Break")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(viewModel.isPaused ? Theme.electric : Theme.textMuted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(viewModel.isPaused ? Theme.electric.opacity(0.15) : Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Settings button
                Button {
                    withAnimation { showSettings = true }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textMuted)
                        .padding(6)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // ── Scrollable Bento Content ──────────────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {

                    // 1. Live Active Session Hero Card
                    BentoHeroCard(viewModel: viewModel)

                    // 2. Middle Row: 2 Tactile Bento Cards
                    HStack(spacing: 10) {
                        BentoScreenTimeCard(viewModel: viewModel)
                        BentoIntensityCard(viewModel: viewModel)
                    }

                    // 3. 7-Day Activity Calendar Strip
                    BentoCalendarStrip(viewModel: viewModel)

                    // 4. Apps Usage Breakdown
                    BentoAppListCard(viewModel: viewModel)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}

// ─── 1. Bento Hero Card (Live Active App) ─────────────────────────────────────

struct BentoHeroCard: View {
    @ObservedObject var viewModel: TrackerViewModel

    var body: some View {
        VStack(spacing: 12) {

            if viewModel.isPaused {
                // ── Coffee Break State ────────────────────────────────────────
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.electric.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.electric)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Coffee Break")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Tracking paused • Resumes in \(formatStopwatch(viewModel.pauseRemaining))")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Theme.textMuted)
                    }

                    Spacer()

                    Button("Resume") {
                        viewModel.resumeNow()
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.neonVolt)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                }
                .padding(14)

            } else {
                // ── Active or Idle State ──────────────────────────────────────
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        // Native Retina App Icon
                        if let appName = viewModel.currentAppName {
                            Image(nsImage: AppIconProvider.shared.icon(
                                for: viewModel.currentBundleId ?? "",
                                appName: appName
                            ))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 42, height: 42)
                                Image(systemName: viewModel.isIdle ? "moon.fill" : "macwindow")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(viewModel.isIdle ? "Mac is Idle" : (viewModel.currentAppName ?? "No App Active"))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)

                                if let domain = viewModel.currentDomain, !viewModel.isIdle {
                                    Text(domain)
                                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.cyan)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.cyan.opacity(0.16))
                                        .clipShape(Capsule())
                                        .lineLimit(1)
                                }
                            }

                            HStack(spacing: 6) {
                                if viewModel.isIdle {
                                    Text("Tracking will resume when you return")
                                        .font(.system(size: 10.5, design: .rounded))
                                        .foregroundStyle(Theme.textMuted)
                                } else if let title = viewModel.currentPageTitle, !title.isEmpty {
                                    LiveEqualizerView()
                                    Text(title)
                                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.textMuted)
                                        .lineLimit(1)
                                } else {
                                    // Mini live equalizer wave bars
                                    LiveEqualizerView()
                                    Text("Active Focus Session")
                                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.textMuted)
                                }
                            }
                        }

                        Spacer()

                        // Big high-contrast stopwatch
                        Text(formatStopwatch(viewModel.currentDuration))
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(viewModel.isIdle ? Theme.textMuted : Theme.neonVolt)
                            .contentTransition(.numericText())
                    }

                }
                .padding(14)
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }
}

// ─── Mini Live Equalizer Waveform ─────────────────────────────────────────────

struct LiveEqualizerView: View {
    @State private var phase: CGFloat = 0.0

    var body: some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.neonVolt)
                .frame(width: 2.5, height: 7)
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.neonVolt)
                .frame(width: 2.5, height: 11)
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.neonVolt)
                .frame(width: 2.5, height: 6)
        }
    }
}

// ─── Micro Metric Cell ────────────────────────────────────────────────────────

struct MicroMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(Theme.textDim)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }
}

// ─── 2. Middle Left: Screen Time & Goal Card ──────────────────────────────────

struct BentoScreenTimeCard: View {
    @ObservedObject var viewModel: TrackerViewModel

    var goalHours: Int { Prefs.dailyGoalHours }
    var goalSeconds: TimeInterval { TimeInterval(goalHours * 3600) }
    var progress: Double {
        guard goalSeconds > 0 else { return 0 }
        return min(1.0, viewModel.totalDuration / goalSeconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SCREEN TIME")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(Theme.textDim)
                Spacer()
                Image(systemName: "hourglass.bottomhalf.filled")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textMuted)
            }

            // Big Bold Screen Time
            Text(formatDurationShort(viewModel.totalDuration))
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            // Tactile Goal Meter (like the habit slider in reference)
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Theme.emerald, Theme.neonVolt],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: max(8, geo.size.width * CGFloat(progress)))
                    }
                }
                .frame(height: 5)

                HStack {
                    Text("\(Int(progress * 100))% of \(goalHours)h goal")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textMuted)
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }
}

// ─── 3. Middle Right: Peak Hours Card ────────────────────────────────────────

struct BentoIntensityCard: View {
    @ObservedObject var viewModel: TrackerViewModel

    /// Top 3 hours by usage, descending
    private var topHours: [HourlyActivity] {
        viewModel.hourlyBars
            .filter { $0.duration > 0 }
            .sorted { $0.duration > $1.duration }
            .prefix(3)
            .map { $0 }
    }

    private var peakDuration: TimeInterval {
        topHours.first?.duration ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header
            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.electric)
                    Text("PEAK HOURS")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(Theme.textDim)
                }
                Spacer()
                Text("Today")
                    .font(.system(size: 9.5, design: .rounded))
                    .foregroundStyle(Theme.textDim)
            }

            // Rows
            if topHours.isEmpty {
                Text("No activity yet")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(topHours.enumerated()), id: \.element.id) { index, bar in
                        HStack(spacing: 8) {
                            // Rank badge
                            Text(index == 0 ? "🥇" : index == 1 ? "🥈" : "🥉")
                                .font(.system(size: 11))

                            // Hour label
                            Text(bar.hourLabel)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(bar.isCurrentHour ? Theme.neonVolt : Theme.textPrimary)
                                .frame(width: 28, alignment: .leading)

                            // Relative bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.06))
                                    Capsule()
                                        .fill(index == 0 ? Theme.neonVolt.opacity(0.7) : Color.white.opacity(0.2))
                                        .frame(width: geo.size.width * CGFloat(bar.duration / peakDuration))
                                }
                            }
                            .frame(height: 5)

                            // Duration
                            Text(formatDurationShort(bar.duration))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(index == 0 ? Theme.neonVolt : Theme.textMuted)
                                .monospacedDigit()
                                .frame(width: 34, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }
}

// ─── 4. Bento 7-Day Activity Calendar Strip ───────────────────────────────────

struct BentoCalendarStrip: View {
    @ObservedObject var viewModel: TrackerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DAILY ACTIVITY")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(Theme.textDim)
                Spacer()
                Text(monthYearFmt.string(from: Date()))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
            }

            // 7 Days Row (inspired by the circular days in reference image)
            HStack(spacing: 6) {
                ForEach(viewModel.sevenDays) { day in
                    let isSelected = (day.dateString == viewModel.selectedDateString)

                    Button {
                        viewModel.selectDate(day.dateString)
                    } label: {
                        VStack(spacing: 5) {
                            Text(day.dayOfWeek)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(isSelected ? .white : Theme.textDim)

                            // Day Number Pill
                            ZStack {
                                Circle()
                                    .fill(
                                        isSelected
                                        ? Theme.neonVolt
                                        : (day.totalDuration > 3600
                                           ? Color.white.opacity(0.12)
                                           : Color.white.opacity(0.05))
                                    )
                                    .frame(width: 28, height: 28)

                                Text(day.dayNumber)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSelected ? .black : (day.totalDuration > 0 ? .white : Theme.textDim))
                            }

                            // Usage Level Dot (Neon volt / orange / dim)
                            Circle()
                                .fill(
                                    day.totalDuration > 7200
                                    ? Theme.neonVolt
                                    : (day.totalDuration > 1800 ? Theme.electric : Color.clear)
                                )
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.white.opacity(0.07) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }
}

// ─── 5. Apps Usage Card ───────────────────────────────────────────────────────

struct BentoAppListCard: View {
    @ObservedObject var viewModel: TrackerViewModel

    var isViewingToday: Bool {
        viewModel.selectedDateString == dateFmt.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header with Apps vs Websites Tab
            HStack {
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            viewModel.isWebsitesView = false
                        }
                    } label: {
                        Text(isViewingToday ? "TODAY'S APPS" : "APPS USED")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(viewModel.isWebsitesView ? Theme.textDim : Theme.neonVolt)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(viewModel.isWebsitesView ? Color.clear : Theme.neonVolt.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if !viewModel.websiteEntries.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                viewModel.isWebsitesView = true
                            }
                        } label: {
                            Text("WEBSITES")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .tracking(0.6)
                                .foregroundStyle(viewModel.isWebsitesView ? Theme.cyan : Theme.textDim)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 6)
                                .background(viewModel.isWebsitesView ? Theme.cyan.opacity(0.12) : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                if viewModel.isWebsitesView {
                    Text("\(viewModel.websiteEntries.count) sites")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textMuted)
                } else {
                    Text("\(viewModel.entries.count) apps")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            if viewModel.isWebsitesView {
                if viewModel.websiteEntries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.textDim)
                        Text("No website usage recorded")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    let maxDuration = viewModel.websiteEntries.first?.duration ?? 1.0

                    VStack(spacing: 6) {
                        ForEach(viewModel.websiteEntries) { entry in
                            let isActive = isViewingToday && (entry.domain == viewModel.currentDomain) && !viewModel.isIdle

                            WebsiteMeterRow(
                                entry: entry,
                                maxDuration: maxDuration,
                                isActive: isActive
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                }
            } else {
                if viewModel.entries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.textDim)
                        Text("No usage recorded for this date")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    let maxDuration = viewModel.entries.first?.duration ?? 1.0

                    VStack(spacing: 6) {
                        ForEach(viewModel.entries) { entry in
                            let isActive = isViewingToday && (entry.name == viewModel.currentAppName) && !viewModel.isIdle

                            AppMeterRow(
                                entry: entry,
                                maxDuration: maxDuration,
                                isActive: isActive
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                }
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }
}

// ─── Single App Row with Expandable Browser Sub-Menu ─────────────────────────

struct AppMeterRow: View {
    let entry: AppSummary
    let maxDuration: TimeInterval
    let isActive: Bool
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {

                // Genuine Retina macOS Icon
                Image(nsImage: AppIconProvider.shared.icon(
                    for: entry.bundleIdentifier,
                    appName: entry.name
                ))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .shadow(color: Color.black.opacity(0.2), radius: 3, y: 1)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.name)
                            .font(.system(size: 12.5, weight: isActive ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(isActive ? .white : Theme.textPrimary)
                            .lineLimit(1)

                        if isActive {
                            Circle().fill(Theme.neonVolt).frame(width: 5, height: 5)
                        }

                        // Sub-menu disclosure toggle button
                        if !entry.websites.isEmpty {
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    isExpanded.toggle()
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 7.5, weight: .bold))
                                    Text("\(entry.websites.count) tabs")
                                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(Theme.cyan)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Theme.cyan.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 4) {
                        Text("\(Int(round(entry.percentage * 100)))% of screen time")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Theme.textDim)

                        if let topDomain = entry.topDomain, entry.websites.isEmpty {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundStyle(Theme.textDim)
                            Text(topDomain)
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.cyan)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Text(formatDuration(entry.duration))
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? Theme.neonVolt : Theme.textMuted)
                    .monospacedDigit()
            }

            // Tactile Progress Line with Rounded Slider Thumb
            GeometryReader { geo in
                let barWidth = max(6, geo.size.width * CGFloat(entry.duration / maxDuration))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 4)

                    Capsule()
                        .fill(
                            isActive
                            ? LinearGradient(colors: [Theme.emerald, Theme.neonVolt], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.18)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: barWidth, height: 4)

                    // Small Glowing Slider Thumb at the tip
                    Circle()
                        .fill(isActive ? Theme.neonVolt : Color.white.opacity(0.7))
                        .frame(width: 7, height: 7)
                        .offset(x: barWidth - 4)
                }
            }
            .frame(height: 7)

            // ─── Nested Browser Tab Sub-Menu ──────────────────────────────────
            if isExpanded && !entry.websites.isEmpty {
                VStack(spacing: 5) {
                    ForEach(entry.websites) { site in
                        WebsiteSubItemRow(
                            site: site,
                            browserDuration: entry.duration
                        )
                    }
                }
                .padding(.top, 4)
                .padding(.leading, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isActive ? Color.white.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// ─── Browser Sub-Menu Item Row ────────────────────────────────────────────────

struct WebsiteSubItemRow: View {
    let site: WebsiteSubItem
    let browserDuration: TimeInterval

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                // Tree branch icon or mini globe
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Theme.textDim)

                    Image(systemName: "globe")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(site.isCurrentlyActive ? Theme.cyan : Theme.textMuted)
                }

                // Domain name
                Text(site.domain)
                    .font(.system(size: 11.5, weight: site.isCurrentlyActive ? .bold : .medium, design: .rounded))
                    .foregroundStyle(site.isCurrentlyActive ? .white : Theme.textPrimary.opacity(0.85))
                    .lineLimit(1)

                if site.isCurrentlyActive {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Theme.cyan)
                            .frame(width: 4, height: 4)
                        Text("Active")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Theme.cyan)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Theme.cyan.opacity(0.15))
                    .clipShape(Capsule())
                }

                Spacer()

                // Sub-item duration
                Text(formatDuration(site.duration))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(site.isCurrentlyActive ? Theme.cyan : Theme.textMuted)
                    .monospacedDigit()
            }

            // Proportional progress bar relative to the parent browser's usage!
            GeometryReader { geo in
                let subWidth = max(4, geo.size.width * CGFloat(site.percentage))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 3)

                    Capsule()
                        .fill(
                            site.isCurrentlyActive
                            ? LinearGradient(colors: [Theme.cyan, Theme.neonVolt], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Theme.cyan.opacity(0.55), Theme.cyan.opacity(0.25)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: subWidth, height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(.vertical, 3.5)
        .padding(.horizontal, 8)
        .background(site.isCurrentlyActive ? Theme.cyan.opacity(0.08) : Color.white.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// ─── Single Website Row ───────────────────────────────────────────────────────

struct WebsiteMeterRow: View {
    let entry: WebsiteSummary
    let maxDuration: TimeInterval
    let isActive: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {

                // Browser Icon with Globe Badge
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: AppIconProvider.shared.icon(
                        for: entry.browserBundle,
                        appName: entry.browserName
                    ))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                    Circle()
                        .fill(Theme.cyan)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Image(systemName: "globe")
                                .font(.system(size: 6.5, weight: .bold))
                                .foregroundStyle(.black)
                        )
                        .offset(x: 2, y: 2)
                }
                .shadow(color: Color.black.opacity(0.2), radius: 3, y: 1)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.domain)
                            .font(.system(size: 12.5, weight: isActive ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(isActive ? .white : Theme.textPrimary)
                            .lineLimit(1)

                        if isActive {
                            Circle().fill(Theme.cyan).frame(width: 5, height: 5)
                        }
                    }

                    HStack(spacing: 4) {
                        Text(entry.browserName)
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.textDim)
                        Text("\(Int(round(entry.percentage * 100)))% of web time")
                            .font(.system(size: 9.5, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                    }
                }

                Spacer()

                Text(formatDuration(entry.duration))
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? Theme.cyan : Theme.textMuted)
                    .monospacedDigit()
            }

            // Progress Bar
            GeometryReader { geo in
                let barWidth = max(6, geo.size.width * CGFloat(entry.duration / maxDuration))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 4)

                    Capsule()
                        .fill(
                            isActive
                            ? LinearGradient(colors: [Theme.cyan, Theme.neonVolt], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Theme.cyan.opacity(0.65), Theme.cyan.opacity(0.35)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: barWidth, height: 4)

                    Circle()
                        .fill(isActive ? Theme.cyan : Color.white.opacity(0.7))
                        .frame(width: 7, height: 7)
                        .offset(x: barWidth - 4)
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isActive ? Color.white.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// ─── Settings View ────────────────────────────────────────────────────────────

struct SettingsView: View {
    @ObservedObject var viewModel: TrackerViewModel
    @Binding var showSettings: Bool

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var trackWebsites    = Prefs.trackWebsitesEnabled
    @State private var hideThreshold    = Prefs.hideThresholdSeconds
    @State private var idleMins         = Prefs.idleThresholdMinutes
    @State private var alertHrs      = Prefs.alertThresholdHours
    @State private var alertsOn      = Prefs.alertsEnabled
    @State private var dailyGoal     = Prefs.dailyGoalHours
    @State private var eyeCareOn     = Prefs.eyeCareEnabled
    @State private var eyeInterval   = Prefs.eyeCareIntervalMinutes
    @State private var eyeSoundOn    = Prefs.eyeCareSoundEnabled
    @State private var showConfirmClear = false

    var body: some View {
        VStack(spacing: 12) {

            // Header
            ZStack {
                Text("Preferences")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                HStack {
                    Button {
                        withAnimation { showSettings = false }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text("Back")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Theme.neonVolt)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.neonVolt.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .frame(height: 28)
            .padding(.horizontal, 16)
            .padding(.top, 14)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {

                    // Launch At Login Card
                    BentoSettingCard {
                        Toggle(isOn: $launchAtLogin) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Launch at Login")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Start silently in menu bar on boot")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { newValue in
                            if newValue { LaunchAtLogin.enable() } else { LaunchAtLogin.disable() }
                        }
                    }

                    // Browser Website Tracking Card
                    BentoSettingCard {
                        Toggle(isOn: $trackWebsites) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Image(systemName: "safari.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Theme.cyan)
                                    Text("Track Active Websites")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                                Text("Log domains in Chrome, Brave, and Safari")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                        .toggleStyle(.switch)
                        .onChange(of: trackWebsites) { newValue in
                            Prefs.trackWebsitesEnabled = newValue
                            viewModel.updateBrowserTrackingSettings()
                        }
                    }

                    // Filter Short Duration / Hide Items Card
                    BentoSettingCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hide Short Items")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Filter out apps & tabs below threshold")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Theme.textMuted)

                            HStack(spacing: 6) {
                                ForEach([
                                    ("30s", 30),
                                    ("1m", 60),
                                    ("3m", 180),
                                    ("5m", 300),
                                    ("Off", 0)
                                ], id: \.1) { opt in
                                    ChipButton(label: opt.0, selected: hideThreshold == opt.1) {
                                        hideThreshold = opt.1
                                        Prefs.hideThresholdSeconds = opt.1
                                        viewModel.updateFilterThreshold(opt.1)
                                    }
                                }
                            }
                        }
                    }

                    // Daily Goal Card
                    BentoSettingCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Daily Screen Time Goal")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Target hours per day")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Theme.textMuted)

                            HStack(spacing: 6) {
                                ForEach([4, 6, 8, 10], id: \.self) { g in
                                    ChipButton(label: "\(g)h", selected: dailyGoal == g) {
                                        dailyGoal = g
                                        Prefs.dailyGoalHours = g
                                    }
                                }
                            }
                        }
                    }

                    // Idle Timeout Card
                    BentoSettingCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Idle Detection Timeout")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Pause tracking after period of inactivity")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Theme.textMuted)

                            HStack(spacing: 6) {
                                ForEach([2, 5, 10, 30, 0], id: \.self) { m in
                                    ChipButton(label: m == 0 ? "Off" : "\(m)m", selected: idleMins == m) {
                                        idleMins = m
                                        Prefs.idleThresholdMinutes = m
                                        viewModel.updateIdleThreshold()
                                    }
                                }
                            }
                        }
                    }

                    // Usage Alert Card
                    BentoSettingCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("App Usage Alert")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Notify when an app exceeds threshold")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Theme.textMuted)

                            HStack(spacing: 6) {
                                ForEach([1, 2, 3, 4], id: \.self) { h in
                                    ChipButton(label: "\(h)h", selected: alertsOn && alertHrs == h) {
                                        alertsOn = true
                                        alertHrs = h
                                        Prefs.alertsEnabled = true
                                        Prefs.alertThresholdHours = h
                                    }
                                }
                                ChipButton(label: "Off", selected: !alertsOn) {
                                    alertsOn = false
                                    Prefs.alertsEnabled = false
                                }
                            }
                        }
                    }

                    // 20-20-20 Eye Health Card
                    BentoSettingCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "eye.fill")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Theme.cyan)
                                        Text("20-20-20 Eye Rule")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                    }
                                    Text("Every 20m, look 20ft away for 20s")
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(Theme.textMuted)
                                }

                                Spacer()

                                Toggle("", isOn: $eyeCareOn)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    .onChange(of: eyeCareOn) { newValue in
                                        Prefs.eyeCareEnabled = newValue
                                        viewModel.updateEyeCareSettings()
                                    }
                            }

                            if eyeCareOn {
                                HStack(spacing: 8) {
                                    Text("Interval:")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.textDim)

                                    ForEach([15, 20, 30], id: \.self) { mins in
                                        ChipButton(label: "\(mins)m", selected: eyeInterval == mins) {
                                            eyeInterval = mins
                                            Prefs.eyeCareIntervalMinutes = mins
                                            viewModel.updateEyeCareSettings()
                                        }
                                    }

                                    Spacer()

                                    Button {
                                        viewModel.triggerEyeCarePreview()
                                    } label: {
                                        HStack(spacing: 3) {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 8))
                                            Text("Test")
                                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                        }
                                        .foregroundStyle(Theme.neonVolt)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Theme.neonVolt.opacity(0.12))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }

                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: eyeSoundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(eyeSoundOn ? Theme.cyan : Theme.textDim)
                                        Text("Chime on start & finish")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundStyle(Theme.textMuted)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $eyeSoundOn)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                        .onChange(of: eyeSoundOn) { newValue in
                                            Prefs.eyeCareSoundEnabled = newValue
                                        }
                                }
                            }
                        }
                    }

                    // Actions Card
                    BentoSettingCard {
                        VStack(spacing: 8) {
                            Button {
                                showConfirmClear = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Clear All Data")
                                    Spacer()
                                }
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.electric)
                            }
                            .buttonStyle(.plain)

                            Rectangle().fill(Theme.border).frame(height: 1)

                            Button {
                                NSApp.terminate(nil)
                            } label: {
                                HStack {
                                    Image(systemName: "power")
                                    Text("Quit MacTimer")
                                    Spacer()
                                    Text("⌘Q")
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(Theme.textDim)
                                }
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .alert(isPresented: $showConfirmClear) {
            Alert(
                title: Text("Clear Tracking History?"),
                message: Text("All recorded app time will be permanently erased."),
                primaryButton: .destructive(Text("Clear All")) {
                    viewModel.clearData()
                },
                secondaryButton: .cancel()
            )
        }
    }
}

// ─── Reusable Setting Card ────────────────────────────────────────────────────

struct BentoSettingCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }
}

// ─── Tactile Chip Button ──────────────────────────────────────────────────────

struct ChipButton: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? .black : Theme.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? Theme.neonVolt : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
